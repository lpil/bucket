import bucket.{type Bucket, type BucketError, type Credentials, Bucket}
import bucket/internal
import bucket/internal/xml
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/option.{type Option}
import gleam/result
import xmlm.{Data, ElementEnd, ElementStart, Name, Tag}

pub type ListAllMyBucketsResult {
  ListAllMyBucketsResult(
    buckets: List(Bucket),
    continuation_token: Option(String),
  )
}

pub fn response(
  response: Response(BitArray),
) -> Result(ListAllMyBucketsResult, BucketError) {
  case response.status {
    200 -> response_success(response)
    403 -> internal.forbidden_error(response)
    got -> Error(bucket.UnexpectedHttpStatusError(expected: 200, got:))
  }
}

fn response_success(
  response: Response(BitArray),
) -> Result(ListAllMyBucketsResult, BucketError) {
  use input <- result.try(xml.start_parsing(response))
  case xmlm.signal(input) {
    Ok(#(ElementStart(Tag(Name(_, "ListAllMyBucketsResult"), _)), input)) ->
      parse_list_all_my_buckets_result(
        input,
        ListAllMyBucketsResult([], option.None),
      )
    Error(e) -> internal.error_xml_syntax(e)
    Ok(#(signal, _)) -> internal.error_xml_format(signal)
  }
}

pub fn request(creds: Credentials) -> Request(BitArray) {
  internal.request(creds, http.Get, "", <<>>)
}

fn parse_list_all_my_buckets_result(
  input: xmlm.Input,
  data: ListAllMyBucketsResult,
) -> Result(ListAllMyBucketsResult, BucketError) {
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
    Error(e) -> internal.error_xml_syntax(e)
    Ok(#(signal, _)) -> internal.error_xml_format(signal)
  }
}

fn parse_buckets(
  input: xmlm.Input,
  data: List(Bucket),
) -> Result(#(List(Bucket), xmlm.Input), BucketError) {
  case xmlm.signal(input) {
    Ok(#(ElementEnd, input)) -> Ok(#(data, input))
    Ok(#(ElementStart(Tag(Name(_, "Bucket"), _)), input)) ->
      case parse_bucket(input, Bucket("", "")) {
        Ok(#(bucket, input)) -> parse_buckets(input, [bucket, ..data])
        Error(e) -> Error(e)
      }
    Error(e) -> internal.error_xml_syntax(e)
    Ok(#(signal, _)) -> internal.error_xml_format(signal)
  }
}

fn parse_bucket(
  input: xmlm.Input,
  data: Bucket,
) -> Result(#(Bucket, xmlm.Input), BucketError) {
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
    Error(e) -> internal.error_xml_syntax(e)
    Ok(#(signal, _)) -> internal.error_xml_format(signal)
  }
}

fn simple_element(
  input: xmlm.Input,
  data: String,
) -> Result(#(String, xmlm.Input), BucketError) {
  case xmlm.signal(input) {
    Ok(#(ElementEnd, input)) -> Ok(#(data, input))
    Ok(#(Data(data), input)) -> simple_element(input, data)
    Error(e) -> internal.error_xml_syntax(e)
    Ok(#(signal, _)) -> internal.error_xml_format(signal)
  }
}

fn skip_element(input: xmlm.Input) -> Result(xmlm.Input, BucketError) {
  case xmlm.signal(input) {
    Ok(#(ElementEnd, input)) -> Ok(input)
    Ok(#(ElementStart(_), input)) ->
      case skip_element(input) {
        Ok(input) -> skip_element(input)
        Error(e) -> Error(e)
      }
    Ok(#(_, input)) -> skip_element(input)
    Error(e) -> internal.error_xml_syntax(e)
  }
}
