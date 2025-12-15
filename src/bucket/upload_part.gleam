//// <https://docs.aws.amazon.com/AmazonS3/latest/API/API_UploadPart.html>

import bucket.{type BucketError, type Credentials}
import bucket/internal
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/option
import gleam/result

pub type UploadPartResult {
  UploadPartResult(etag: String)
}

/// The parameters for the API request
///
/// The `part_number` can be any number from 1 to 10,000, inclusive. A part number uniquely identifies a part and also defines its position within the object being created. If you upload a new part using the same part number that was used with a previous part, the previously uploaded part is overwritten.
pub type RequestBuilder {
  RequestBuilder(
    bucket: String,
    key: String,
    upload_id: String,
    part_number: Int,
    body: BitArray,
  )
}

pub fn request(
  bucket bucket: String,
  key key: String,
  upload_id upload_id: String,
  part_number part_number: Int,
  body body: BitArray,
) -> RequestBuilder {
  RequestBuilder(bucket:, key:, upload_id:, part_number:, body:)
}

pub fn build(builder: RequestBuilder, creds: Credentials) -> Request(BitArray) {
  internal.request(
    creds,
    http.Put,
    "/" <> builder.bucket <> "/" <> builder.key,
    [
      #("partNumber", option.Some(int.to_string(builder.part_number))),
      #("uploadId", option.Some(builder.upload_id)),
    ],
    [],
    builder.body,
  )
}

pub fn response(
  response: Response(BitArray),
) -> Result(UploadPartResult, BucketError) {
  case response.status {
    200 -> response_success(response)
    _ -> internal.s3_error(response)
  }
}

fn response_success(
  response: Response(BitArray),
) -> Result(UploadPartResult, BucketError) {
  let etag = list.key_find(response.headers, "etag") |> result.unwrap("")
  Ok(UploadPartResult(etag:))
}
