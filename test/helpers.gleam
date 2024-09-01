import bucket
import bucket/create_bucket
import bucket/delete_bucket
import bucket/list_buckets
import gleam/http
import gleam/httpc
import gleam/list
import gleam/option

pub const creds = bucket.Credentials(
  scheme: http.Http,
  port: option.Some(9000),
  host: "localhost",
  region: "us-east-1",
  access_key_id: "minioadmin",
  secret_access_key: "miniopass",
)

pub const bad_creds = bucket.Credentials(
  scheme: http.Http,
  port: option.Some(9000),
  host: "localhost",
  region: "us-east-1",
  access_key_id: "unknown",
  secret_access_key: "nope",
)

pub fn create_bucket(name: String) -> Nil {
  let req = create_bucket.request(name:) |> create_bucket.build(creds)
  let assert Ok(res) = httpc.send_bits(req)
  let assert Ok(Nil) = create_bucket.response(res)
  Nil
}

pub fn delete_existing_buckets() -> Nil {
  list.each(get_existing_bucket_names(), fn(name) {
    let req = delete_bucket.request(name:) |> delete_bucket.build(creds)
    let assert Ok(res) = httpc.send_bits(req)
    let assert Ok(Nil) = delete_bucket.response(res)
  })
}

pub fn get_existing_bucket_names() -> List(String) {
  let assert Ok(res) = list_buckets.request(creds) |> httpc.send_bits
  let assert Ok(res) = list_buckets.response(res)
  list.map(res.buckets, fn(b) { b.name })
}
