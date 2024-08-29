import aws4_request
import bucket.{
  type Credentials, type S3Error, UnexpectedXmlFormatError, XmlSyntaxError,
}
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/option
import xmlm

pub fn error_xml_syntax(e: xmlm.InputError) -> Result(a, S3Error) {
  Error(XmlSyntaxError(xmlm.input_error_to_string(e)))
}

pub fn error_xml_format(signal: xmlm.Signal) -> Result(a, S3Error) {
  Error(UnexpectedXmlFormatError(xmlm.signal_to_string(signal)))
}

pub fn request(
  creds: Credentials,
  method: http.Method,
  path: String,
  body: BitArray,
) -> Request(BitArray) {
  let request =
    Request(
      method,
      [],
      body,
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
