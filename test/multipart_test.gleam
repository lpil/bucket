import bucket.{ErrorObject, S3Error}
import bucket/complete_multipart_upload
import bucket/create_multipart_upload
import bucket/upload_part
import gleam/bit_array
import gleam/httpc
import gleam/list
import gleam/string
import gleeunit/should
import helpers

/// Perform a basic multipart upload and verify it works as expected
pub fn perform_multipart_upload_test() {
  // Set up a test bucket
  helpers.delete_existing_buckets()
  let bucket = "multipart"
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
  let contents = helpers.get_object(bucket, key)
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

/// S3 allows us to discard parts when completing a multipart upload
pub fn complete_upload_skip_parts_test() {
  // Set up a test bucket
  helpers.delete_existing_buckets()
  let bucket = "multipart"
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

  // Upload some parts
  let upload_id = res.upload_id
  let part_size = 5 * 1024 * 1024
  let part1 = helpers.get_random_bytes(part_size)
  let part2 = helpers.get_random_bytes(part_size)
  let part3 = helpers.get_random_bytes(part_size)
  let part4 = <<"Goodbye!":utf8>>
  let parts =
    [part1, part2, part3, part4]
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

  // Complete the multipart upload, but discard part1 and part4
  let assert [_, p2, p3, _] = parts
  let parts = [p2, p3]
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
  let contents = helpers.get_object(bucket, key)
  should.equal(bit_array.byte_size(contents), 2 * part_size)
  should.equal(
    bit_array.slice(from: contents, at: 0, take: part_size),
    Ok(part2),
  )
  should.equal(
    bit_array.slice(from: contents, at: part_size, take: part_size),
    Ok(part3),
  )
}

/// Attempt to complete a multipart upload with parts smaller than the minimum size
pub fn entity_too_small_test() {
  // Set up a test bucket
  helpers.delete_existing_buckets()
  let bucket = "multipart"
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

  // Upload the parts
  let upload_id = res.upload_id
  let part_size = 2 * 1024 * 1024
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
  let assert Error(res) = complete_multipart_upload.response(res)
  let assert S3Error(
    http_status:,
    error: ErrorObject(code:, message:, request_id:, resource:),
  ) = res

  http_status
  |> should.equal(400)

  code
  |> should.equal("EntityTooSmall")

  message
  |> should.equal(
    "Your proposed upload is smaller than the minimum allowed object size.",
  )

  request_id
  |> should.not_equal("")

  resource
  |> should.equal("/" <> bucket <> "/" <> key)
}

/// Attempt to complete a multipart upload with an incorrect ETag in one of the parts
pub fn invalid_part_test() {
  // Set up a test bucket
  helpers.delete_existing_buckets()
  let bucket = "multipart"
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

  // Complete the multipart upload, no need to upload parts for this test
  let upload_id = res.upload_id
  let parts = [
    complete_multipart_upload.Part(part_number: 1, etag: "incorrect"),
    complete_multipart_upload.Part(part_number: 2, etag: "also incorrect"),
  ]
  let assert Ok(res) =
    complete_multipart_upload.request(bucket:, key:, upload_id:, parts:)
    |> complete_multipart_upload.build(helpers.creds)
    |> httpc.send_bits
  let assert Error(res) = complete_multipart_upload.response(res)
  let assert S3Error(
    http_status:,
    error: ErrorObject(code:, message:, request_id:, resource:),
  ) = res

  http_status
  |> should.equal(400)

  code
  |> should.equal("InvalidPart")

  message
  |> should.equal(
    "One or more of the specified parts could not be found.  The part may not have been uploaded, or the specified entity tag may not match the part's entity tag.",
  )

  request_id
  |> should.not_equal("")

  resource
  |> should.equal("/" <> bucket <> "/" <> key)
}

/// Attempt to complete a multipart upload with parts in an invalid order
pub fn invalid_part_order_test() {
  // Set up a test bucket
  helpers.delete_existing_buckets()
  let bucket = "multipart"
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

  // Upload the parts
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

  // Complete the multipart upload, with the parts in an incorrect order
  let parts = list.reverse(parts)
  let assert Ok(res) =
    complete_multipart_upload.request(bucket:, key:, upload_id:, parts:)
    |> complete_multipart_upload.build(helpers.creds)
    |> httpc.send_bits
  let assert Error(res) = complete_multipart_upload.response(res)
  let assert S3Error(
    http_status:,
    error: ErrorObject(code:, message:, request_id:, resource:),
  ) = res

  http_status
  |> should.equal(400)

  code
  |> should.equal("InvalidPartOrder")

  message
  |> should.equal(
    "The list of parts was not in ascending order. The parts list must be specified in order by part number.",
  )

  request_id
  |> should.not_equal("")

  resource
  |> should.equal("/" <> bucket <> "/" <> key)
}

/// Attempt to upload a part with incorrect upload_id
pub fn no_such_upload_test() {
  // Set up a test bucket
  helpers.delete_existing_buckets()
  let bucket = "multipart"
  helpers.create_bucket(bucket)

  // Upload a part
  let expired_id =
    "OWM1ZmM2MDEtNGRkOS00ZTU0LTk3MTUtMjYxMGVlZGY3NDRhLmNiNTQ5OWI5LTg5NTktNDg2Ni04NjkzLTYyNGIxODcxYzAzNXgxNzYzNTY3MTk4ODc1NzAzMTQ4"
  let key = "test/myfile"
  let part_body = helpers.get_random_bytes(5 * 1024 * 1024)
  let assert Ok(res) =
    upload_part.request(
      bucket:,
      key:,
      upload_id: expired_id,
      part_number: 1,
      body: part_body,
    )
    |> upload_part.build(helpers.creds)
    |> httpc.send_bits
  let assert Error(res) = upload_part.response(res)
  let assert S3Error(
    http_status:,
    error: ErrorObject(code:, message:, request_id:, resource:),
  ) = res

  http_status
  |> should.equal(404)

  code
  |> should.equal("NoSuchUpload")

  message
  |> should.equal(
    "The specified multipart upload does not exist. The upload ID may be invalid, or the upload may have been aborted or completed.",
  )

  request_id
  |> should.not_equal("")

  resource
  |> should.equal("/" <> bucket <> "/" <> key)
}
