import bucket
import bucket/create_bucket
import bucket/list_buckets.{ListAllMyBucketsResult}
import gleam/http
import gleam/httpc
import gleam/option
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

const creds = bucket.Credentials(
  scheme: http.Http,
  port: option.Some(9000),
  host: "localhost",
  region: "us-east-1",
  access_key_id: "minioadmin",
  secret_access_key: "miniopass",
)

// TODO: invalid creds
// TODO: whatever other error codes
pub fn list_buckets__no_buckets_test() {
  let assert Ok(res) = list_buckets.request(creds) |> httpc.send_bits
  let assert Ok(res) = list_buckets.response(res)
  res
  |> should.equal(ListAllMyBucketsResult(
    buckets: [],
    continuation_token: option.None,
  ))
}

pub fn create_buckets_test() {
  let req =
    create_bucket.request(name: "bucket1")
    |> create_bucket.build(creds)

  req.body
  |> should.equal(<<
    "<CreateBucketConfiguration xmlns=\"http://s3.amazonaws.com/doc/2006-03-01/\">",
    "<LocationConstraint>us-east-1</LocationConstraint>",
    "</CreateBucketConfiguration>",
  >>)

  let assert Ok(res) = httpc.send_bits(req)
  let assert Ok(Nil) = create_bucket.response(res)
}
