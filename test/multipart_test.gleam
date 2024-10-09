import bucket/complete_multipart_upload
import bucket/create_multipart_upload
import bucket/get_object
import bucket/upload_part
import gleam/bit_array
import gleam/httpc
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

  // Upload some parts (they can be sent in parallel)
  // NOTE: The minimum Part size for multipart upload is 5MiB, except the last part.
  let upload_id = res.upload_id
  let part_size = 5 * 1024 * 1024
  let part1 = helpers.get_random_bytes(part_size)
  let part2 = helpers.get_random_bytes(part_size)
  let part3 = <<"Goodbye!":utf8>>
  let parts =
    [part1, part2, part3]
    |> list.index_map(fn(body, i) {
      let part_number = i + 1
      let assert Ok(res) =
        upload_part.request(bucket:, key:, upload_id:, part_number:, body:)
        |> upload_part.build(helpers.creds)
        |> httpc.send_bits
      let assert Ok(res) = upload_part.response(res)
      should.not_equal(res.etag, "")
      complete_multipart_upload.Part(part_number:, etag: res.etag)
    })

  // Complete the multipart upload
  let assert Ok(res) =
    complete_multipart_upload.request(bucket:, key:, upload_id:, parts:)
    |> complete_multipart_upload.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(res) = complete_multipart_upload.response(res)
  should.be_true(string.contains(res.location, "/" <> bucket <> "/" <> key))
  should.equal(res.bucket, bucket)
  should.equal(res.key, key)
  should.not_equal(res.etag, "")

  // Get the uploaded object and verify its contents
  let assert Ok(res) =
    get_object.request(bucket, key)
    |> get_object.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(get_object.Found(contents)) = get_object.response(res)
  should.equal(bit_array.byte_size(contents), 2 * part_size + 8)
  should.equal(
    bit_array.slice(from: contents, at: 0, take: part_size),
    Ok(part1),
  )
  should.equal(
    bit_array.slice(from: contents, at: part_size, take: part_size),
    Ok(part2),
  )
  should.equal(
    bit_array.slice(from: contents, at: 2 * part_size, take: 8),
    Ok(part3),
  )
}
