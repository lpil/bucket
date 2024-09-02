import bucket
import bucket/create_bucket
import bucket/delete_bucket
import bucket/list_buckets.{ListAllMyBucketsResult}
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
  let assert bucket.S3Error(
    http_status:,
    code:,
    message:,
    request_id:,
    resource:,
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
  let assert Error(bucket.S3Error(
    http_status: 400,
    code: "InvalidBucketName",
    ..,
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
  let assert Error(bucket.S3Error(
    http_status: 409,
    code: "BucketAlreadyOwnedByYou",
    ..,
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
  let assert Error(bucket.S3Error(http_status: 404, code: "NoSuchBucket", ..)) =
    delete_bucket.response(res)
}
