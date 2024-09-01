import bucket.{
  type BucketError, type Credentials, InvalidXmlSyntaxError,
  UnexpectedXmlFormatError,
}
import gleam/dict.{type Dict}
import gleam/function
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/option
import gleam/result
import xmlm.{Data, ElementEnd, ElementStart}

pub fn error_xml_syntax(e: xmlm.InputError) -> Result(a, BucketError) {
  Error(InvalidXmlSyntaxError(xmlm.input_error_to_string(e)))
}

pub fn error_xml_format(signal: xmlm.Signal) -> Result(a, BucketError) {
  Error(UnexpectedXmlFormatError(xmlm.signal_to_string(signal)))
}

pub fn start_parsing(
  response: Response(BitArray),
) -> Result(xmlm.Input, BucketError) {
  let input = xmlm.from_bit_array(response.body)
  case xmlm.signal(input) {
    Error(e) -> error_xml_syntax(e)
    Ok(#(xmlm.Dtd(_), input)) -> Ok(input)
    Ok(#(_, _)) -> Ok(input)
  }
}

pub type ElementParser(parent) {
  ElementParser(
    tag: String,
    handler: fn(parent, xmlm.Input) ->
      Result(#(parent, xmlm.Input), BucketError),
  )
}

pub type ElementParserBuilder(data) {
  ElementParserBuilder(
    data: data,
    tag: String,
    children: Dict(
      String,
      fn(data, xmlm.Input) -> Result(#(data, xmlm.Input), BucketError),
    ),
  )
}

pub fn parse(
  parser: fn(xmlm.Input) -> Result(#(output, xmlm.Input), BucketError),
  input: xmlm.Input,
) -> Result(output, BucketError) {
  case parser(input) {
    Ok(#(data, _)) -> Ok(data)
    Error(e) -> Error(e)
  }
}

pub fn finish(
  builder: ElementParserBuilder(data),
) -> fn(xmlm.Input) -> Result(#(data, xmlm.Input), BucketError) {
  map_finish(builder, function.identity)
}

pub fn map_finish(
  builder: ElementParserBuilder(data),
  mapper: fn(data) -> output,
) -> fn(xmlm.Input) -> Result(#(output, xmlm.Input), BucketError) {
  fn(input) {
    case xmlm.signal(input) {
      Error(e) -> error_xml_syntax(e)
      Ok(#(ElementStart(xmlm.Tag(xmlm.Name(_, name), _)), input))
        if name == builder.tag
      -> {
        case parse_element(builder.data, builder.children, input) {
          Ok(#(data, input)) -> Ok(#(mapper(data), input))
          Error(e) -> Error(e)
        }
      }
      Ok(#(signal, _)) -> error_xml_format(signal)
    }
  }
}

pub fn child(
  builder: ElementParserBuilder(parent_data),
  tag: String,
  reduce: fn(parent_data, child_data) -> parent_data,
  parse: fn(xmlm.Input) -> Result(#(child_data, xmlm.Input), BucketError),
) -> ElementParserBuilder(parent_data) {
  let handler = fn(parent_data, input) {
    case parse(input) {
      Ok(#(child_data, input)) -> Ok(#(reduce(parent_data, child_data), input))
      Error(error) -> Error(error)
    }
  }
  ElementParserBuilder(
    ..builder,
    children: dict.insert(builder.children, tag, handler),
  )
}

pub fn element(tag: String, data: data) -> ElementParserBuilder(data) {
  ElementParserBuilder(tag:, data:, children: dict.new())
}

fn parse_element(
  data: data,
  handlers: Dict(
    String,
    fn(data, xmlm.Input) -> Result(#(data, xmlm.Input), BucketError),
  ),
  input: xmlm.Input,
) {
  case xmlm.signal(input) {
    Ok(#(ElementEnd, input)) -> Ok(#(data, input))
    Error(e) -> error_xml_syntax(e)
    Ok(#(ElementStart(xmlm.Tag(xmlm.Name(_, name), _)) as signal, input)) -> {
      case dict.get(handlers, name) {
        Ok(handler) ->
          case handler(data, input) {
            Ok(#(data, input)) -> parse_element(data, handlers, input)
            Error(e) -> Error(e)
          }
        Error(_) -> error_xml_format(signal)
      }
    }
    Ok(#(signal, _)) -> error_xml_format(signal)
  }
}

pub fn text_element(
  input: xmlm.Input,
) -> Result(#(String, xmlm.Input), BucketError) {
  parse_text_element("", input)
}

fn parse_text_element(
  data: String,
  input: xmlm.Input,
) -> Result(#(String, xmlm.Input), BucketError) {
  case xmlm.signal(input) {
    Ok(#(ElementEnd, input)) -> Ok(#(data, input))
    Ok(#(Data(data), input)) -> parse_text_element(data, input)
    Error(e) -> error_xml_syntax(e)
    Ok(#(signal, _)) -> error_xml_format(signal)
  }
}
