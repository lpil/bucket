import bucket/create_multipart_upload
import bucket/upload_part
import gleam/httpc
import gleam/list
import gleeunit/should
import helpers

pub fn perform_multipart_upload_test() {
  // Set up a test bucket
  helpers.delete_existing_buckets()
  let bucket = "multipart1"
  helpers.create_bucket(bucket)

  // Initiate a multipart upload
  let key = "test/file"
  let assert Ok(res) =
    create_multipart_upload.request(bucket:, key:)
    |> create_multipart_upload.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(res) = create_multipart_upload.response(res)
  should.equal(res.bucket, bucket)
  should.equal(res.key, key)
  should.not_equal(res.upload_id, "")

  // Upload some parts (they can be sent in any order)
  let upload_id = res.upload_id
  [
    #(<<"jumps over ":utf8>>, 2),
    #(<<"The quick brown fox ":utf8>>, 1),
    #(<<"the lazy dog.":utf8>>, 3),
  ]
  |> list.map(fn(pair) {
    let #(body, part_number) = pair
    let assert Ok(res) =
      upload_part.request(bucket:, key:, upload_id:, part_number:, body:)
      |> upload_part.build(helpers.creds)
      |> httpc.send_bits
    let assert Ok(res) = upload_part.response(res)
    should.not_equal(res.etag, "")
  })
}
