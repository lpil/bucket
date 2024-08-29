import bucket.{ListAllMyBucketsResult}
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

pub fn list_no_buckets_test() {
  let req = bucket.list_buckets_request(creds)
  let assert Ok(res) = httpc.send_bits(req)
  let assert Ok(res) = bucket.list_buckets_response(res)
  res
  |> should.equal(ListAllMyBucketsResult(
    buckets: [],
    continuation_token: option.None,
  ))
}
