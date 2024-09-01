import bucket.{type BucketError, InvalidXmlSyntaxError, UnexpectedXmlFormatError}
import gleam/dict.{type Dict}
import gleam/function
import gleam/result
import xmlm

pub fn error_xml_syntax(e: xmlm.InputError) -> Result(a, BucketError) {
  Error(InvalidXmlSyntaxError(xmlm.input_error_to_string(e)))
}

fn error_xml_format(signal: Signal) -> Result(a, BucketError) {
  Error(
    UnexpectedXmlFormatError(case signal {
      Open(name) -> "open " <> name
      Close -> "close"
      Data(data) -> data
    }),
  )
}

fn start_parsing(input: xmlm.Input) -> Result(xmlm.Input, BucketError) {
  case xmlm.signal(input) {
    Error(e) -> error_xml_syntax(e)
    Ok(#(xmlm.Dtd(_), input)) -> Ok(input)
    Ok(#(_, _)) -> Ok(input)
  }
}

pub type ElementParser(data, output) {
  ElementParser(
    data: data,
    tag: String,
    mapper: fn(data) -> output,
    children: Dict(
      String,
      fn(data, xmlm.Input) -> Result(#(data, xmlm.Input), BucketError),
    ),
  )
}

type Signal {
  Open(name: String)
  Close
  Data(String)
}

fn signal(input: xmlm.Input) -> Result(#(Signal, xmlm.Input), xmlm.InputError) {
  case xmlm.signal(input) {
    Ok(#(xmlm.ElementStart(xmlm.Tag(xmlm.Name(_, name), _)), input)) ->
      Ok(#(Open(name), input))
    Ok(#(xmlm.ElementEnd, input)) -> Ok(#(Close, input))
    Ok(#(xmlm.Data(data), input)) -> Ok(#(Data(data), input))
    Ok(#(xmlm.Dtd(_), input)) -> signal(input)
    Error(e) -> Error(e)
  }
}

pub fn parse(
  parser: ElementParser(data, output),
  input: BitArray,
) -> Result(output, BucketError) {
  let input = xmlm.from_bit_array(input)
  use input <- result.try(start_parsing(input))
  use input <- result.try(case signal(input) {
    Error(e) -> error_xml_syntax(e)
    Ok(#(Open(tag), input)) if tag == parser.tag -> Ok(input)
    Ok(#(signal, _)) -> error_xml_format(signal)
  })
  case finish(parser)(input) {
    Ok(#(data, _)) -> Ok(parser.mapper(data))
    Error(e) -> Error(e)
  }
}

pub fn map(
  builder: ElementParser(data, output1),
  mapper: fn(output1) -> output2,
) -> ElementParser(data, output2) {
  let ElementParser(data:, mapper: prevous_mapper, tag:, children:) = builder
  ElementParser(data:, tag:, children:, mapper: fn(data) {
    mapper(prevous_mapper(data))
  })
}

fn finish(
  builder: ElementParser(data, output),
) -> fn(xmlm.Input) -> Result(#(data, xmlm.Input), BucketError) {
  fn(input) { parse_element(builder.data, builder.children, input) }
}

pub fn keep_text(
  builder: ElementParser(parent_data, output),
  tag: String,
  reduce: fn(parent_data, String) -> parent_data,
) -> ElementParser(parent_data, output) {
  let handler = fn(parent_data, input) {
    case text_element(input) {
      Ok(#(child_data, input)) -> Ok(#(reduce(parent_data, child_data), input))
      Error(error) -> Error(error)
    }
  }
  ElementParser(
    ..builder,
    children: dict.insert(builder.children, tag, handler),
  )
}

pub fn keep(
  builder: ElementParser(parent_data, output),
  child: ElementParser(child_data, child_output),
  reduce: fn(parent_data, child_output) -> parent_data,
) -> ElementParser(parent_data, output) {
  let parse = finish(child)
  let handler = fn(parent_data, input) {
    case parse(input) {
      Ok(#(child_data, input)) ->
        Ok(#(reduce(parent_data, child.mapper(child_data)), input))
      Error(error) -> Error(error)
    }
  }
  ElementParser(
    ..builder,
    children: dict.insert(builder.children, child.tag, handler),
  )
}

pub fn element(tag: String, data: data) -> ElementParser(data, data) {
  ElementParser(tag:, data:, children: dict.new(), mapper: function.identity)
}

fn parse_element(
  data: data,
  handlers: Dict(
    String,
    fn(data, xmlm.Input) -> Result(#(data, xmlm.Input), BucketError),
  ),
  input: xmlm.Input,
) {
  case signal(input) {
    Error(e) -> error_xml_syntax(e)
    Ok(#(Close, input)) -> Ok(#(data, input))
    Ok(#(Open(name), input)) -> {
      case dict.get(handlers, name) {
        Ok(handler) ->
          case handler(data, input) {
            Ok(#(data, input)) -> parse_element(data, handlers, input)
            Error(e) -> Error(e)
          }
        Error(_) ->
          case skip(input, 0) {
            Ok(input) -> parse_element(data, handlers, input)
            Error(e) -> Error(e)
          }
      }
    }
    Ok(#(signal, _)) -> error_xml_format(signal)
  }
}

fn skip(input: xmlm.Input, depth: Int) -> Result(xmlm.Input, BucketError) {
  case signal(input) {
    Ok(#(Close, input)) if depth <= 0 -> Ok(input)
    Ok(#(Close, input)) -> skip(input, depth - 1)
    Ok(#(Open(_), input)) -> skip(input, depth + 1)
    Ok(#(_, input)) -> skip(input, depth)
    Error(e) -> error_xml_syntax(e)
  }
}

fn text_element(input: xmlm.Input) -> Result(#(String, xmlm.Input), BucketError) {
  parse_text_element("", input)
}

fn parse_text_element(
  data: String,
  input: xmlm.Input,
) -> Result(#(String, xmlm.Input), BucketError) {
  case signal(input) {
    Ok(#(Close, input)) -> Ok(#(data, input))
    Ok(#(Data(data), input)) -> parse_text_element(data, input)
    Error(e) -> error_xml_syntax(e)
    Ok(#(signal, _)) -> error_xml_format(signal)
  }
}
