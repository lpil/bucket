//// <https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html>

import bucket.{type BucketError, type Credentials}
import bucket/internal
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}

/// The parameters for the API request
pub type RequestBuilder {
  RequestBuilder(bucket: String, key: String)
}

pub type Outcome(body) {
  Found(body)
  NotFound
}

pub fn request(bucket bucket: String, key key: String) -> RequestBuilder {
  RequestBuilder(bucket:, key:)
}

pub fn build(builder: RequestBuilder, creds: Credentials) -> Request(BitArray) {
  let headers = []
  internal.request(
    creds,
    http.Get,
    "/" <> builder.bucket <> "/" <> builder.key,
    [],
    headers,
    <<>>,
  )
}

pub fn response(response: Response(body)) -> Result(Outcome(body), BucketError) {
  case response.status {
    200 -> Ok(Found(response.body))
    404 -> Ok(NotFound)
    _ ->
      Error(bucket.UnexpectedResponseError(response.set_body(response, <<>>)))
  }
}
