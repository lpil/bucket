import bucket/presign_object
import gleam/http
import gleam/http/request
import gleam/httpc
import gleam/uri
import gleeunit/should
import helpers

pub fn presigned_get_test() {
  helpers.delete_existing_buckets()
  helpers.create_bucket("test-bucket")
  let content = <<"Hello from Gleam!":utf8>>
  helpers.create_object("test-bucket", "test.txt", content)

  let url_string =
    presign_object.get_object("test-bucket", "test.txt")
    |> presign_object.expires_in(600)
    |> presign_object.build(helpers.creds)

  let assert Ok(parsed_uri) = uri.parse(url_string)

  let assert Ok(req) = request.from_uri(parsed_uri)

  let req = request.set_body(req, <<>>)

  let assert Ok(res) = httpc.send_bits(req)

  res.status |> should.equal(200)
  res.body |> should.equal(content)
}

pub fn presigned_put_test() {
  helpers.delete_existing_buckets()
  helpers.create_bucket("upload-bucket")
  let upload_content = <<"This was uploaded via URL":utf8>>

  let url_string =
    presign_object.put_object("upload-bucket", "upload.txt")
    |> presign_object.expires_in(600)
    |> presign_object.build(helpers.creds)

  let assert Ok(parsed_uri) = uri.parse(url_string)

  let assert Ok(req) = request.from_uri(parsed_uri)

  let req =
    req
    |> request.set_method(http.Put)
    |> request.set_body(upload_content)

  let assert Ok(res) = httpc.send_bits(req)

  res.status |> should.equal(200)

  helpers.get_object("upload-bucket", "upload.txt")
  |> should.equal(upload_content)
}
