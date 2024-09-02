import bucket.{type BucketError, type Credentials}
import bucket/internal
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/option.{type Option}

pub type RequestBuilder {
  RequestBuilder(name: String, expected_bucket_owner: Option(String))
}

pub fn request(name name: String) -> RequestBuilder {
  RequestBuilder(name:, expected_bucket_owner: option.None)
}

/// The account ID of the expected bucket owner. If the account ID that you
/// provide does not match the actual owner of the bucket, the request fails with
/// the HTTP status code 403 Forbidden (access denied).
///
pub fn expected_bucket_owner(
  builder: RequestBuilder,
  expected_bucket_owner: String,
) -> RequestBuilder {
  RequestBuilder(
    ..builder,
    expected_bucket_owner: option.Some(expected_bucket_owner),
  )
}

pub fn build(builder: RequestBuilder, creds: Credentials) -> Request(BitArray) {
  internal.request(creds, http.Delete, "/" <> builder.name, [], [], <<>>)
}

pub fn response(response: Response(BitArray)) -> Result(Nil, BucketError) {
  case response.status {
    204 -> Ok(Nil)
    _ -> internal.s3_error(response)
  }
}
