import gleam/http.{type Scheme}
import gleam/option.{type Option}

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
