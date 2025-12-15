//// <https://docs.aws.amazon.com/AmazonS3/latest/API/API_HeadObject.html>

import bucket.{type BucketError, type Credentials}
import bucket/internal
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/option.{type Option}

/// The parameters for the API request
pub type RequestBuilder {
  RequestBuilder(
    bucket: String,
    key: String,
    if_match: Option(String),
    expected_bucket_owner: Option(String),
  )
}

pub type Outcome {
  Found
  NotFound
  PreconditionFailed
}

pub fn request(bucket bucket: String, key key: String) -> RequestBuilder {
  RequestBuilder(
    bucket:,
    key:,
    if_match: option.None,
    expected_bucket_owner: option.None,
  )
}

/// Return the object only if its entity tag (ETag) is the same as the one
/// specified; otherwise, return a 412 (precondition failed) error.
/// 
/// If both of the If-Match and If-Unmodified-Since headers are present in the
/// request as follows:
/// 
/// If-Match condition evaluates to true, and;
/// If-Unmodified-Since condition evaluates to false;
/// Then Amazon S3 returns 200 OK and the data requested.
/// 
/// For more information about conditional requests, see RFC 7232.
/// <https://datatracker.ietf.org/doc/html/rfc7232>
pub fn if_match(builder: RequestBuilder, etag etag: String) -> RequestBuilder {
  RequestBuilder(..builder, if_match: option.Some(etag))
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
  let headers = []
  let headers = case builder.if_match {
    option.Some(etag) -> [#("if-match", etag), ..headers]
    _ -> headers
  }
  internal.request(
    creds,
    http.Head,
    "/" <> builder.bucket <> "/" <> builder.key,
    [],
    headers,
    <<>>,
  )
}

pub fn response(response: Response(BitArray)) -> Result(Outcome, BucketError) {
  case response.status {
    200 -> Ok(Found)
    404 -> Ok(NotFound)
    412 -> Ok(PreconditionFailed)
    _ -> internal.s3_error(response)
  }
}
