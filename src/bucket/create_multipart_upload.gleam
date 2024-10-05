import bucket.{type BucketError, type Credentials}
import bucket/internal
import bucket/internal/xml
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/option

pub type CreateMultipartUploadResult {
  CreateMultipartUploadResult(bucket: String, key: String, upload_id: String)
}

/// The parameters for the API request
pub type RequestBuilder {
  RequestBuilder(bucket: String, key: String)
}

pub fn request(bucket bucket: String, key key: String) -> RequestBuilder {
  RequestBuilder(bucket:, key:)
}

pub fn build(builder: RequestBuilder, creds: Credentials) -> Request(BitArray) {
  internal.request(
    creds,
    http.Post,
    "/" <> builder.bucket <> "/" <> builder.key,
    [#("uploads", option.Some(""))],
    [],
    <<>>,
  )
}

pub fn response(
  response: Response(BitArray),
) -> Result(CreateMultipartUploadResult, BucketError) {
  case response.status {
    200 -> response_success(response)
    _ -> internal.s3_error(response)
  }
}

fn response_success(
  response: Response(BitArray),
) -> Result(CreateMultipartUploadResult, BucketError) {
  xml.element(
    "InitiateMultipartUploadResult",
    CreateMultipartUploadResult("", "", ""),
  )
  |> xml.keep_text("Bucket", fn(r, v) {
    CreateMultipartUploadResult(..r, bucket: v)
  })
  |> xml.keep_text("Key", fn(r, v) { CreateMultipartUploadResult(..r, key: v) })
  |> xml.keep_text("UploadId", fn(r, v) {
    CreateMultipartUploadResult(..r, upload_id: v)
  })
  |> xml.parse(response.body)
}
