import bucket.{type BucketError, type Credentials}
import bucket/internal
import bucket/internal/xml
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/option.{type Option}

pub type ListObjectsResult {
  ListObjectsResult(is_truncated: Bool, contents: List(Object))
}

pub type Object {
  Object(key: String, last_modified: String, etag: String, size: Int)
}

/// The parameters for the API request
pub type RequestBuilder {
  RequestBuilder(
    bucket: String,
    prefix: Option(String),
    start_after: Option(String),
    max_keys: Option(Int),
  )
}

pub fn request(bucket: String) -> RequestBuilder {
  RequestBuilder(
    bucket:,
    prefix: option.None,
    start_after: option.None,
    max_keys: option.None,
  )
}

/// Limits the response to keys that begin with the specified prefix.
///
pub fn prefix(builder: RequestBuilder, prefix: String) -> RequestBuilder {
  RequestBuilder(..builder, prefix: option.Some(prefix))
}

/// StartAfter is where you want Amazon S3 to start listing from. Amazon S3
/// starts listing after this specified key. StartAfter can be any key in the
/// bucket.
///
pub fn start_after(builder: RequestBuilder, key: String) -> RequestBuilder {
  RequestBuilder(..builder, start_after: option.Some(key))
}

pub fn build(builder: RequestBuilder, creds: Credentials) -> Request(BitArray) {
  let query = [
    #("start-after", builder.start_after),
    #("max-keys", builder.max_keys |> option.map(int.to_string)),
    #("prefix", builder.prefix),
  ]
  internal.request(creds, http.Get, "/" <> builder.bucket, query, [], <<>>)
}

pub fn response(
  response: Response(BitArray),
) -> Result(ListObjectsResult, BucketError) {
  case response.status {
    200 -> response_success(response)
    _ -> internal.s3_error(response)
  }
}

fn response_success(
  response: Response(BitArray),
) -> Result(ListObjectsResult, BucketError) {
  let object =
    xml.element("Contents", Object("", "", "", 0))
    |> xml.keep_text("Key", fn(b, n) { Object(..b, key: n) })
    |> xml.keep_text("LastModified", fn(b, n) { Object(..b, last_modified: n) })
    |> xml.keep_text("ETag", fn(b, n) { Object(..b, etag: n) })
    |> xml.keep_int("Size", fn(b, n) { Object(..b, size: n) })

  let default = ListObjectsResult(is_truncated: False, contents: [])
  xml.element("ListBucketResult", default)
  |> xml.keep_bool("IsTruncated", fn(d, b) {
    ListObjectsResult(..d, is_truncated: b)
  })
  |> xml.keep(object, fn(d, b) {
    ListObjectsResult(..d, contents: [b, ..d.contents])
  })
  |> xml.parse(response.body)
}
