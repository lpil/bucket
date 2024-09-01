import bucket.{type Bucket, type BucketError, type Credentials, Bucket}
import bucket/internal
import bucket/internal/xml
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/option.{type Option}

pub type ListAllMyBucketsResult {
  ListAllMyBucketsResult(
    buckets: List(Bucket),
    continuation_token: Option(String),
  )
}

pub fn response(
  response: Response(BitArray),
) -> Result(ListAllMyBucketsResult, BucketError) {
  case response.status {
    200 -> response_success(response)
    403 -> internal.forbidden_error(response)
    got -> Error(bucket.UnexpectedHttpStatusError(expected: 200, got:))
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
  |> xml.parse(response.body)
}

pub fn request(creds: Credentials) -> Request(BitArray) {
  internal.request(creds, http.Get, "", <<>>)
}
