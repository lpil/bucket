import bucket
import bucket/create_bucket
import bucket/delete_bucket
import bucket/delete_objects
import bucket/get_object
import bucket/head_object
import bucket/list_buckets
import bucket/list_objects
import bucket/put_object
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

pub fn create_object(bucket: String, key: String, body: BitArray) -> Nil {
  let assert Ok(res) =
    put_object.request(bucket:, key:, body:)
    |> put_object.build(creds)
    |> httpc.send_bits
  let assert Ok(_) = put_object.response(res)
  Nil
}

pub fn delete_existing_buckets() -> Nil {
  list.each(get_existing_bucket_names(), delete_bucket)
}

pub fn get_existing_bucket_names() -> List(String) {
  let assert Ok(res) =
    list_buckets.request()
    |> list_buckets.max_buckets(100)
    |> list_buckets.build(creds)
    |> httpc.send_bits
  let assert Ok(res) = list_buckets.response(res)
  list.map(res.buckets, fn(b) { b.name })
}

fn delete_bucket(name: String) -> Nil {
  let req = list_objects.request(name) |> list_objects.build(creds)
  let assert Ok(res) = httpc.send_bits(req)
  let assert Ok(listed) = list_objects.response(res)

  case listed.contents {
    [] -> Nil
    _ -> {
      let objects =
        list.map(listed.contents, fn(c) {
          delete_objects.ObjectIdentifier(key: c.key, version_id: option.None)
        })
      let req =
        delete_objects.request(name, objects) |> delete_objects.build(creds)
      let assert Ok(res) = httpc.send_bits(req)
      let assert Ok(_) = delete_objects.response(res)
      Nil
    }
  }

  case listed.is_truncated {
    True -> delete_bucket(name)
    False -> {
      let req = delete_bucket.request(name:) |> delete_bucket.build(creds)
      let assert Ok(res) = httpc.send_bits(req)
      let assert Ok(Nil) = delete_bucket.response(res)
      Nil
    }
  }
}

pub fn does_object_exist(bucket: String, key: String) -> Bool {
  let assert Ok(res) =
    head_object.request(bucket, key)
    |> head_object.build(creds)
    |> httpc.send_bits
  let assert Ok(res) = head_object.response(res)
  res == head_object.Found
}

pub fn get_object(bucket: String, key: String) -> BitArray {
  let assert Ok(res) =
    get_object.request(bucket, key)
    |> get_object.build(creds)
    |> httpc.send_bits
  let assert Ok(get_object.Found(contents)) = get_object.response(res)
  contents
}

@external(erlang, "rand", "bytes")
pub fn get_random_bytes(num_bytes: Int) -> BitArray
