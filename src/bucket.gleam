import gleam/http/response.{type Response}
import gleam/option.{type Option}
import gleam/uri

pub type BucketError {
  InvalidXmlSyntaxError(String)
  UnexpectedXmlFormatError(String)
  UnexpectedResponseError(Response(BitArray))
  S3Error(http_status: Int, error: ErrorObject)
}

/// An error from S3.
pub type ErrorObject {
  ErrorObject(
    code: String,
    message: String,
    resource: String,
    request_id: String,
  )
}

/// The creds used to connect to an S3 API.
pub type Credentials {
  Credentials(
    scheme: Option(String),
    port: Option(Int),
    host: Option(String),
    region: String,
    access_key_id: String,
    secret_access_key: String,
    session_token: Option(String),
  )
}

pub fn credentials(
  base_url: String,
  access_key_id: String,
  secret_access_key: String,
) -> Credentials {
  let assert Ok(parsed_url) = uri.parse(base_url)

  Credentials(
    host: parsed_url.host,
    port: parsed_url.port,
    scheme: parsed_url.scheme,
    region: "eu-west-1",
    access_key_id:,
    secret_access_key:,
    session_token: option.None,
  )
}

/// Set the region for the credentials.
pub fn with_region(creds: Credentials, region: String) -> Credentials {
  Credentials(..creds, region:)
}

/// Set the optional session token, which could have given via a task or
/// instance role if these are used within your deployment environment.
pub fn with_session_token(
  creds: Credentials,
  session_token: option.Option(String),
) -> Credentials {
  Credentials(..creds, session_token: session_token)
}

pub type Bucket {
  Bucket(name: String, creation_date: String)
}
