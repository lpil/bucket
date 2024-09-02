import bucket.{ErrorObject, S3Error}
import bucket/create_bucket
import bucket/delete_bucket
import bucket/delete_objects
import bucket/list_buckets.{ListAllMyBucketsResult}
import bucket/list_objects
import bucket/put_object
import gleam/httpc
import gleam/list
import gleam/option
import gleam/uri
import gleeunit
import gleeunit/should
import helpers

pub fn main() {
  gleeunit.main()
}

pub fn list_buckets_bad_creds_test() {
  let assert Ok(res) =
    list_buckets.request()
    |> list_buckets.build(helpers.bad_creds)
    |> httpc.send_bits
  let assert Error(res) = list_buckets.response(res)
  let assert S3Error(
    http_status:,
    error: ErrorObject(code:, message:, request_id:, resource:),
  ) = res

  http_status
  |> should.equal(403)

  code
  |> should.equal("InvalidAccessKeyId")

  message
  |> should.equal(
    "The Access Key Id you provided does not exist in our records.",
  )

  request_id
  |> should.not_equal("")

  resource
  |> should.equal("/")
}

pub fn list_buckets_test() {
  helpers.delete_existing_buckets()

  let assert Ok(res) =
    list_buckets.request()
    |> list_buckets.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(res) = list_buckets.response(res)
  res
  |> should.equal(ListAllMyBucketsResult(
    buckets: [],
    continuation_token: option.None,
  ))

  helpers.create_bucket("bucket1")
  helpers.create_bucket("bucket2")
  helpers.create_bucket("bucket3")

  let assert Ok(res) =
    list_buckets.request()
    |> list_buckets.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(res) = list_buckets.response(res)
  res.continuation_token
  |> should.equal(option.None)
  res.buckets
  |> list.map(fn(b) { b.name })
  |> should.equal(["bucket3", "bucket2", "bucket1"])
}

pub fn create_bucket_test() {
  helpers.delete_existing_buckets()

  let req =
    create_bucket.request(name: "bucket1")
    |> create_bucket.build(helpers.creds)
  req.body
  |> should.equal(<<
    "<CreateBucketConfiguration xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">":utf8,
    "<LocationConstraint>us-east-1</LocationConstraint>":utf8,
    "</CreateBucketConfiguration>":utf8,
  >>)
  let assert Ok(res) = httpc.send_bits(req)
  let assert Ok(Nil) = create_bucket.response(res)

  let assert Ok(res) =
    create_bucket.request(name: "bucket2")
    |> create_bucket.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(Nil) = create_bucket.response(res)

  helpers.get_existing_bucket_names()
  |> should.equal(["bucket2", "bucket1"])
}

pub fn create_bucket_invalid_test() {
  helpers.delete_existing_buckets()

  let req =
    create_bucket.request(name: uri.percent_encode("%%%"))
    |> create_bucket.build(helpers.creds)
  req.body
  |> should.equal(<<
    "<CreateBucketConfiguration xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">":utf8,
    "<LocationConstraint>us-east-1</LocationConstraint>":utf8,
    "</CreateBucketConfiguration>":utf8,
  >>)
  let assert Ok(res) = httpc.send_bits(req)
  let assert Error(S3Error(
    http_status: 400,
    error: ErrorObject(
      code: "InvalidBucketName",
      ..,
    ),
  )) = create_bucket.response(res)

  helpers.get_existing_bucket_names()
  |> should.equal([])
}

pub fn create_bucket_already_created_test() {
  helpers.delete_existing_buckets()
  helpers.create_bucket("bucket1")

  let req =
    create_bucket.request(name: "bucket1")
    |> create_bucket.build(helpers.creds)
  req.body
  |> should.equal(<<
    "<CreateBucketConfiguration xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">":utf8,
    "<LocationConstraint>us-east-1</LocationConstraint>":utf8,
    "</CreateBucketConfiguration>":utf8,
  >>)
  let assert Ok(res) = httpc.send_bits(req)
  let assert Error(S3Error(
    http_status: 409,
    error: ErrorObject(
      code: "BucketAlreadyOwnedByYou",
      ..,
    ),
  )) = create_bucket.response(res)

  helpers.get_existing_bucket_names()
  |> should.equal(["bucket1"])
}

pub fn delete_test() {
  helpers.delete_existing_buckets()

  helpers.create_bucket("bucket1")
  helpers.create_bucket("bucket2")
  helpers.create_bucket("bucket3")

  let assert Ok(res) =
    delete_bucket.request(name: "bucket2")
    |> delete_bucket.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(Nil) = delete_bucket.response(res)

  helpers.get_existing_bucket_names()
  |> should.equal(["bucket3", "bucket1"])

  let assert Ok(res) =
    delete_bucket.request(name: "bucket3")
    |> delete_bucket.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(Nil) = delete_bucket.response(res)

  helpers.get_existing_bucket_names()
  |> should.equal(["bucket1"])
}

pub fn delete_not_found_test() {
  helpers.delete_existing_buckets()

  let assert Ok(res) =
    delete_bucket.request(name: "bucket1")
    |> delete_bucket.build(helpers.creds)
    |> httpc.send_bits
  let assert Error(S3Error(
    http_status: 404,
    error: ErrorObject(
      code: "NoSuchBucket",
      ..,
    ),
  )) = delete_bucket.response(res)
}

pub fn put_object_test() {
  helpers.delete_existing_buckets()
  helpers.create_bucket("bucket")

  let assert Ok(res) =
    put_object.request(bucket: "bucket", key: "my/object/1", body: <<
      "Hello, Joe!":utf8,
    >>)
    |> put_object.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(put_object.PutObjectResult(etag:)) = put_object.response(res)
  etag |> should.not_equal("")
}

pub fn list_objects_test() {
  helpers.delete_existing_buckets()
  helpers.create_bucket("bucket")
  helpers.create_object("bucket", "o/1", <<"one":utf8>>)
  helpers.create_object("bucket", "o/2", <<"two":utf8>>)
  helpers.create_object("bucket", "o/3", <<"three":utf8>>)

  let assert Ok(res) =
    list_objects.request("bucket")
    |> list_objects.build(helpers.creds)
    |> httpc.send_bits
  let assert Ok(list_objects.ListObjectsResult(
    is_truncated: False,
    contents: [object3, object2, object1],
  )) = list_objects.response(res)

  let assert list_objects.Object(key: "o/1", last_modified:, etag:, size: 3) =
    object1
  etag |> should.not_equal("")
  last_modified |> should.not_equal("")
  let assert list_objects.Object(key: "o/2", size: 3, ..) = object2
  let assert list_objects.Object(key: "o/3", size: 5, ..) = object3
}

pub fn delete_objects_test() {
  helpers.delete_existing_buckets()
  helpers.create_bucket("bucket")
  helpers.create_object("bucket", "o/1", <<"one":utf8>>)
  helpers.create_object("bucket", "o/2", <<"two":utf8>>)
  helpers.create_object("bucket", "o/3", <<"three":utf8>>)

  let assert Ok(res) =
    delete_objects.request("bucket", [
      delete_objects.ObjectIdentifier(key: "o/1", version_id: option.None),
      delete_objects.ObjectIdentifier(key: "o/2", version_id: option.None),
      delete_objects.ObjectIdentifier(key: "o/3", version_id: option.None),
    ])
    |> delete_objects.build(helpers.creds)
    |> httpc.send_bits

  let assert Ok([
    Ok(delete_objects.Deleted(key: "o/3", version_id: "")),
    Ok(delete_objects.Deleted(key: "o/2", version_id: "")),
    Ok(delete_objects.Deleted(key: "o/1", version_id: "")),
  ]) = delete_objects.response(res)
}
// TODO: delete objects partial failure
