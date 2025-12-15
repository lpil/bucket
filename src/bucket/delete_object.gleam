import bucket.{type BucketError, type Credentials}
import bucket/internal
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}

/// The parameters for the API request
pub type RequestBuilder {
  RequestBuilder(bucket: String, key: String)
}

pub fn request(bucket bucket: String, key key: String) -> RequestBuilder {
  RequestBuilder(bucket:, key:)
}

pub fn build(builder: RequestBuilder, creds: Credentials) -> Request(BitArray) {
  let query = []
  let headers = []
  internal.request(
    creds,
    http.Delete,
    "/" <> builder.bucket <> "/" <> builder.key,
    query,
    headers,
    <<>>,
  )
}

pub fn response(response: Response(BitArray)) -> Result(Nil, BucketError) {
  case response.status {
    204 -> Ok(Nil)
    _ -> internal.s3_error(response)
  }
}
