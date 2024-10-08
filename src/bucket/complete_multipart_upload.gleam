import bucket.{type BucketError, type Credentials}
import bucket/internal
import bucket/internal/xml
import gleam/bit_array
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/list
import gleam/option
import gleam/string_builder
import xmb

pub type CompleteMultipartUploadResult {
  CompleteMultipartUploadResult(
    location: String,
    bucket: String,
    key: String,
    etag: String,
  )
}

/// The parameters for the API request
pub type RequestBuilder {
  RequestBuilder(
    bucket: String,
    key: String,
    upload_id: String,
    parts: List(Part),
  )
}

pub type Part {
  Part(part_number: Int, etag: String)
}

pub fn request(
  bucket bucket: String,
  key key: String,
  upload_id upload_id: String,
  parts parts: List(Part),
) -> RequestBuilder {
  let parts =
    // Sort parts by part_number so the user doesn't have to. If the parts weren't sorted,
    // the CompleteMultipartUpload request would fail.
    list.sort(parts, fn(a, b) { int.compare(a.part_number, b.part_number) })
  RequestBuilder(bucket:, key:, upload_id:, parts:)
}

pub fn build(builder: RequestBuilder, creds: Credentials) -> Request(BitArray) {
  let body =
    xmb.x(
      "CompleteMultipartUpload",
      [#("xmlns", "http://s3.amazonaws.com/doc/2006-03-01/")],
      list.map(builder.parts, fn(part) {
        xmb.x("Part", [], [
          xmb.x("PartNumber", [], [xmb.text(int.to_string(part.part_number))]),
          xmb.x("ETag", [], [xmb.text(part.etag)]),
        ])
      }),
    )
    |> xmb.render_fragment
    |> string_builder.to_string
    |> bit_array.from_string
  internal.request(
    creds,
    http.Post,
    "/" <> builder.bucket <> "/" <> builder.key,
    [#("uploadId", option.Some(builder.upload_id))],
    [],
    body,
  )
}

pub fn response(
  response: Response(BitArray),
) -> Result(CompleteMultipartUploadResult, BucketError) {
  case response.status {
    200 -> response_success(response)
    _ -> internal.s3_error(response)
  }
}

fn response_success(
  response: Response(BitArray),
) -> Result(CompleteMultipartUploadResult, BucketError) {
  xml.element(
    "CompleteMultipartUploadResult",
    CompleteMultipartUploadResult("", "", "", ""),
  )
  |> xml.keep_text("Location", fn(r, v) {
    CompleteMultipartUploadResult(..r, location: v)
  })
  |> xml.keep_text("Bucket", fn(r, v) {
    CompleteMultipartUploadResult(..r, bucket: v)
  })
  |> xml.keep_text("Key", fn(r, v) {
    CompleteMultipartUploadResult(..r, key: v)
  })
  |> xml.keep_text("ETag", fn(r, v) {
    CompleteMultipartUploadResult(..r, etag: v)
  })
  |> xml.parse(response.body)
}
