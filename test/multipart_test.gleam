import bucket/create_multipart_upload
import gleam/httpc
import gleeunit/should
import helpers

pub fn perform_multipart_upload_test() {
  helpers.delete_existing_buckets()
  helpers.create_bucket("multipart1")

  // Initiate a multipart upload
  let assert Ok(res) =
    create_multipart_upload.request(bucket: "multipart1", key: "test/file")
    |> create_multipart_upload.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(res) = create_multipart_upload.response(res)
  should.equal(res.bucket, "multipart1")
  should.equal(res.key, "test/file")
  should.not_equal(res.upload_id, "")
}
