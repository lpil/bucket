import gleam/http.{type Scheme}
import gleam/http/response.{type Response}
import gleam/option.{type Option}

pub type BucketError {
  InvalidXmlSyntaxError(String)
  UnexpectedXmlFormatError(String)
  UnexpectedResponseError(Response(BitArray))
  S3Error(
    http_status: Int,
    code: String,
    message: String,
    resource: String,
    request_id: String,
  )
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
