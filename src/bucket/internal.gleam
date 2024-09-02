import aws4_request
import bucket.{
  type BucketError, type Credentials, InvalidXmlSyntaxError,
  UnexpectedXmlFormatError,
}
import bucket/internal/xml
import gleam/dict.{type Dict}
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{type Option}
import gleam/uri
import xmlm

pub fn error_xml_syntax(e: xmlm.InputError) -> Result(a, BucketError) {
  Error(InvalidXmlSyntaxError(xmlm.input_error_to_string(e)))
}

pub fn error_xml_format(signal: xmlm.Signal) -> Result(a, BucketError) {
  Error(UnexpectedXmlFormatError(xmlm.signal_to_string(signal)))
}

pub fn request(
  creds: Credentials,
  method: http.Method,
  path: String,
  query: List(#(String, Option(String))),
  body: BitArray,
) -> Request(BitArray) {
  let query =
    query
    |> list.filter_map(fn(pair) {
      case pair.1 {
        option.Some(value) -> Ok(#(pair.0, value))
        _ -> Error(Nil)
      }
    })
    |> uri.query_to_string
  let query = case query {
    "" -> option.None
    _ -> option.Some(query)
  }
  let request =
    Request(method, [], body, creds.scheme, creds.host, creds.port, path, query)
  aws4_request.signer(
    creds.access_key_id,
    creds.secret_access_key,
    creds.region,
    "s3",
  )
  |> aws4_request.sign_bits(request)
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

type S3Err {
  S3Error(
    http_status: Int,
    code: String,
    message: String,
    resource: String,
    request_id: String,
  )
}

fn s3_error_to_bucket_error(t) {
  let S3Error(http_status:, code:, message:, resource:, request_id:) = t
  bucket.S3Error(http_status:, code:, message:, resource:, request_id:)
}

pub fn forbidden_error(response: Response(BitArray)) -> Result(a, BucketError) {
  let parsed =
    xml.element("Error", S3Error(response.status, "", "", "", ""))
    |> xml.keep_text("Code", fn(error, code) { S3Error(..error, code:) })
    |> xml.keep_text("Message", fn(error, message) {
      S3Error(..error, message:)
    })
    |> xml.keep_text("Resource", fn(error, resource) {
      S3Error(..error, resource:)
    })
    |> xml.keep_text("RequestId", fn(error, request_id) {
      S3Error(..error, request_id:)
    })
    |> xml.map(s3_error_to_bucket_error)
    |> xml.parse(response.body)

  case parsed {
    Ok(e) -> Error(e)
    Error(e) -> Error(e)
  }
}
