import aws4_request
import bucket.{
  type BucketError, type Credentials, type ErrorObject, ErrorObject,
  InvalidXmlSyntaxError, UnexpectedXmlFormatError,
}
import bucket/internal/xml.{type ElementParser}
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
  creds creds: Credentials,
  method method: http.Method,
  path path: String,
  query query: List(#(String, Option(String))),
  headers headers: List(#(String, String)),
  body body: BitArray,
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
    Request(
      method,
      headers,
      body,
      creds.scheme,
      creds.host,
      creds.port,
      path,
      query,
    )
  aws4_request.signer(
    creds.access_key_id,
    creds.secret_access_key,
    creds.region,
    "s3",
  )
  |> with_session_token(creds)
  |> aws4_request.sign_bits(request)
}

pub fn error_object() -> ElementParser(ErrorObject, ErrorObject) {
  xml.element("Error", ErrorObject("", "", "", ""))
  |> xml.keep_text("Code", fn(error, code) { ErrorObject(..error, code:) })
  |> xml.keep_text("Message", fn(error, message) {
    ErrorObject(..error, message:)
  })
  |> xml.keep_text("Resource", fn(error, resource) {
    ErrorObject(..error, resource:)
  })
  |> xml.keep_text("RequestId", fn(error, request_id) {
    ErrorObject(..error, request_id:)
  })
}

pub fn s3_error(response: Response(BitArray)) -> Result(a, BucketError) {
  let parsed =
    error_object()
    |> xml.map(bucket.S3Error(response.status, _))
    |> xml.parse(response.body)

  case parsed {
    Ok(e) -> Error(e)
    Error(_) -> Error(bucket.UnexpectedResponseError(response))
  }
}

fn with_session_token(
  signer: aws4_request.Signer,
  creds: Credentials,
) -> aws4_request.Signer {
  case creds.session_token {
    option.None -> signer
    option.Some(session_token) ->
      aws4_request.with_session_token(signer, session_token)
  }
}
