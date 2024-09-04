import bucket.{type Bucket, type BucketError, type Credentials, Bucket}
import bucket/internal
import bucket/internal/xml
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/option.{type Option}

pub type ListAllMyBucketsResult {
  ListAllMyBucketsResult(
    buckets: List(Bucket),
    continuation_token: Option(String),
  )
}

/// The parameters for the API request
pub type RequestBuilder {
  RequestBuilder(continuation_token: Option(String), max_buckets: Option(Int))
}

pub fn request() -> RequestBuilder {
  RequestBuilder(option.None, option.None)
}

/// ContinuationToken indicates to Amazon S3 that the list is being continued
/// on this bucket with a token. ContinuationToken is obfuscated and is not a
/// real key. You can use this ContinuationToken for pagination of the list
/// results.
pub fn continuation_token(
  builder: RequestBuilder,
  token: String,
) -> RequestBuilder {
  RequestBuilder(..builder, continuation_token: option.Some(token))
}

/// Maximum number of buckets to be returned in response. When the number is
/// more than the count of buckets that are owned by an AWS account, return all
/// the buckets in response.
/// 
/// Valid Range: Minimum value of 1. Maximum value of 1000.
///
pub fn max_buckets(builder: RequestBuilder, count: Int) -> RequestBuilder {
  RequestBuilder(..builder, max_buckets: option.Some(count))
}

pub fn build(builder: RequestBuilder, creds: Credentials) -> Request(BitArray) {
  let query = [
    #("continuation-token", builder.continuation_token),
    #("max-buckets", option.map(builder.max_buckets, int.to_string)),
  ]
  internal.request(creds, http.Get, "", query, [], <<>>)
}

pub fn response(
  response: Response(BitArray),
) -> Result(ListAllMyBucketsResult, BucketError) {
  case response.status {
    200 -> response_success(response)
    _ -> internal.s3_error(response)
  }
}

fn response_success(
  response: Response(BitArray),
) -> Result(ListAllMyBucketsResult, BucketError) {
  let bucket =
    xml.element("Bucket", Bucket("", ""))
    |> xml.keep_text("Name", fn(b, n) { Bucket(..b, name: n) })
    |> xml.keep_text("CreationDate", fn(b, d) { Bucket(..b, creation_date: d) })

  let buckets =
    xml.element("Buckets", [])
    |> xml.keep(bucket, fn(buckets, bucket) { [bucket, ..buckets] })

  xml.element("ListAllMyBucketsResult", ListAllMyBucketsResult([], option.None))
  |> xml.keep(buckets, fn(d, b) { ListAllMyBucketsResult(..d, buckets: b) })
  |> xml.keep_text("ContinuationToken", fn(d, b) {
    ListAllMyBucketsResult(..d, continuation_token: option.Some(b))
  })
  |> xml.parse(response.body)
}
