import aws4_request
import gleam/bit_array
import gleam/http.{type Scheme}
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/option.{type Option}
import gleam/result
import xmlm.{Data, ElementEnd, ElementStart, Name, Tag}

pub type S3Error {
  XmlSyntaxError(String)
  UnexpectedXmlFormatError(String)
}

pub type Credentials {
  Credentials(
    scheme: Scheme,
    port: Option(Int),
    host: String,
    region: String,
    access_key_id: String,
    secret_access_key: String,
  )
}

pub type Bucket {
  Bucket(name: String, creation_date: String)
}

pub type ListAllMyBucketsResult {
  ListAllMyBucketsResult(
    buckets: List(Bucket),
    continuation_token: Option(String),
  )
}

pub fn list_buckets_request(creds: Credentials) -> Request(BitArray) {
  request(creds, "")
}

fn error_xml_syntax(e: xmlm.InputError) -> Result(_, S3Error) {
  Error(XmlSyntaxError(xmlm.input_error_to_string(e)))
}

fn error_xml_format(signal: xmlm.Signal) -> Result(_, S3Error) {
  Error(UnexpectedXmlFormatError(xmlm.signal_to_string(signal)))
}

pub fn list_buckets_response(
  response: Response(BitArray),
) -> Result(ListAllMyBucketsResult, S3Error) {
  use input <- result.try(start_parsing(response))
  case xmlm.signal(input) {
    Ok(#(ElementStart(Tag(Name(_, "ListAllMyBucketsResult"), _)), input)) ->
      parse_list_all_my_buckets_result(
        input,
        ListAllMyBucketsResult([], option.None),
      )
    Error(e) -> error_xml_syntax(e)
    Ok(#(signal, _)) -> error_xml_format(signal)
  }
}

fn parse_list_all_my_buckets_result(
  input: xmlm.Input,
  data: ListAllMyBucketsResult,
) -> Result(ListAllMyBucketsResult, S3Error) {
  case xmlm.signal(input) {
    Ok(#(ElementEnd, _)) -> Ok(data)
    Ok(#(ElementStart(Tag(Name(_, "Buckets"), _)), input)) ->
      case parse_buckets(input, []) {
        Ok(#(buckets, input)) -> {
          let data = ListAllMyBucketsResult(..data, buckets:)
          parse_list_all_my_buckets_result(input, data)
        }
        Error(e) -> Error(e)
      }
    Ok(#(ElementStart(Tag(Name(_, "Owner"), _)), input)) ->
      case skip_element(input) {
        Ok(input) -> parse_list_all_my_buckets_result(input, data)
        Error(e) -> Error(e)
      }
    Error(e) -> error_xml_syntax(e)
    Ok(#(signal, _)) -> error_xml_format(signal)
  }
}

fn parse_buckets(
  input: xmlm.Input,
  data: List(Bucket),
) -> Result(#(List(Bucket), xmlm.Input), S3Error) {
  case xmlm.signal(input) {
    Ok(#(ElementEnd, input)) -> Ok(#(data, input))
    Ok(#(ElementStart(Tag(Name(_, "Bucket"), _)), input)) ->
      case parse_bucket(input, Bucket("", "")) {
        Ok(#(bucket, input)) -> parse_buckets(input, [bucket, ..data])
        Error(e) -> Error(e)
      }
    Error(e) -> error_xml_syntax(e)
    Ok(#(signal, _)) -> error_xml_format(signal)
  }
}

fn parse_bucket(
  input: xmlm.Input,
  data: Bucket,
) -> Result(#(Bucket, xmlm.Input), S3Error) {
  case xmlm.signal(input) {
    Ok(#(ElementEnd, input)) -> Ok(#(data, input))
    Ok(#(ElementStart(Tag(Name(_, "Name"), _)), input)) ->
      case simple_element(input, "") {
        Ok(#(name, input)) -> parse_bucket(input, Bucket(..data, name:))
        Error(e) -> Error(e)
      }
    Ok(#(ElementStart(Tag(Name(_, "CreationDate"), _)), input)) ->
      case simple_element(input, "") {
        Ok(#(creation_date, input)) ->
          parse_bucket(input, Bucket(..data, creation_date:))
        Error(e) -> Error(e)
      }
    Error(e) -> error_xml_syntax(e)
    Ok(#(signal, _)) -> error_xml_format(signal)
  }
}

fn simple_element(
  input: xmlm.Input,
  data: String,
) -> Result(#(String, xmlm.Input), S3Error) {
  case xmlm.signal(input) {
    Ok(#(ElementEnd, input)) -> Ok(#(data, input))
    Ok(#(Data(data), input)) -> simple_element(input, data)
    Error(e) -> error_xml_syntax(e)
    Ok(#(signal, _)) -> error_xml_format(signal)
  }
}

fn skip_element(input: xmlm.Input) -> Result(xmlm.Input, S3Error) {
  case xmlm.signal(input) {
    Ok(#(ElementEnd, input)) -> Ok(input)
    Ok(#(ElementStart(_), input)) ->
      case skip_element(input) {
        Ok(input) -> skip_element(input)
        Error(e) -> Error(e)
      }
    Ok(#(_, input)) -> skip_element(input)
    Error(e) -> error_xml_syntax(e)
  }
}

fn start_parsing(response: Response(BitArray)) -> Result(xmlm.Input, S3Error) {
  let input = xmlm.from_bit_array(response.body)
  case xmlm.signal(input) {
    Error(e) -> error_xml_syntax(e)
    Ok(#(xmlm.Dtd(_), input)) -> Ok(input)
    Ok(#(_, _)) -> Ok(input)
  }
}

fn request(creds: Credentials, path: String) -> Request(BitArray) {
  let request =
    Request(
      http.Get,
      [],
      <<>>,
      creds.scheme,
      creds.host,
      creds.port,
      path,
      option.None,
    )
  aws4_request.signer(
    creds.access_key_id,
    creds.secret_access_key,
    creds.region,
    "s3",
  )
  |> aws4_request.sign_bits(request)
}
