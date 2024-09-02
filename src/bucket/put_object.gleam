import bucket.{type BucketError, type Credentials}
import bucket/internal
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/list
import gleam/result

pub type PutObjectResult {
  PutObjectResult(etag: String)
}

pub type RequestBuilder {
  RequestBuilder(bucket: String, key: String, body: BitArray)
}

pub fn request(
  bucket bucket: String,
  key key: String,
  body body: BitArray,
) -> RequestBuilder {
  RequestBuilder(bucket:, key:, body:)
}

pub fn build(builder: RequestBuilder, creds: Credentials) -> Request(BitArray) {
  internal.request(
    creds,
    http.Put,
    "/" <> builder.bucket <> "/" <> builder.key,
    [],
    [],
    builder.body,
  )
}

pub fn response(
  response: Response(BitArray),
) -> Result(PutObjectResult, BucketError) {
  case response.status {
    200 -> response_success(response)
    _ -> internal.s3_error(response)
  }
}

fn response_success(
  response: Response(BitArray),
) -> Result(PutObjectResult, BucketError) {
  let etag = list.key_find(response.headers, "etag") |> result.unwrap("")
  Ok(PutObjectResult(etag:))
}
