import bucket/complete_multipart_upload
import bucket/create_multipart_upload
import bucket/get_object
import bucket/upload_part
import gleam/bit_array
import gleam/httpc
import gleam/int
import gleam/list
import gleam/string
import gleeunit/should
import helpers

pub fn perform_multipart_upload_test() {
  // Set up a test bucket
  helpers.delete_existing_buckets()
  let bucket = "multipart1"
  helpers.create_bucket(bucket)

  // Initiate a multipart upload
  let key = "test/myfile"
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
  // NOTE: The minimum Part size for multipart upload is 5MiB (hardcoded in minio)
  let megabyte = 1024 * 1024
  let parts =
    [
      #(string.repeat("B", 5 * megabyte) |> bit_array.from_string, 2),
      #(string.repeat("A", 5 * megabyte) |> bit_array.from_string, 1),
      #(<<"Goodbye!":utf8>>, 3),
    ]
    |> list.map(fn(pair) {
      let #(body, part_number) = pair
      let assert Ok(res) =
        upload_part.request(bucket:, key:, upload_id:, part_number:, body:)
        |> upload_part.build(helpers.creds)
        |> httpc.send_bits
      let assert Ok(res) = upload_part.response(res)
      should.not_equal(res.etag, "")
      complete_multipart_upload.Part(part_number:, etag: res.etag)
    })

  // Complete the multipart upload
  // NOTE: The Parts must be sorted in ascending order for this operation
  let parts =
    list.sort(parts, fn(pa, pb) { int.compare(pa.part_number, pb.part_number) })
  let assert Ok(res) =
    complete_multipart_upload.request(bucket:, key:, upload_id:, parts:)
    |> complete_multipart_upload.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(res) = complete_multipart_upload.response(res)
  should.be_true(string.contains(res.location, "/" <> bucket <> "/" <> key))
  should.equal(res.bucket, bucket)
  should.equal(res.key, key)
  should.not_equal(res.etag, "")

  // Get the object and verify its contents
  let assert Ok(res) =
    get_object.request(bucket, key)
    |> get_object.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(get_object.Found(contents)) = get_object.response(res)
  should.equal(bit_array.byte_size(contents), 2 * 5 * megabyte + 8)
  let assert Ok(<<"AAAA":utf8>>) =
    bit_array.slice(from: contents, at: 1, take: 4)
  let assert Ok(<<"AABB":utf8>>) =
    bit_array.slice(from: contents, at: 5 * megabyte - 2, take: 4)
  let assert Ok(<<"BBGoodbye!":utf8>>) =
    bit_array.slice(from: contents, at: 2 * 5 * megabyte + 8, take: -10)
}
