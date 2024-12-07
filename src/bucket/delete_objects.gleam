import bucket.{type BucketError, type Credentials, type ErrorObject, ErrorObject}
import bucket/internal
import bucket/internal/xml
import gleam/bit_array
import gleam/crypto
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string_tree
import xmb

/// The parameters for the API request
pub type RequestBuilder {
  RequestBuilder(bucket: String, objects: List(ObjectIdentifier))
}

pub type ObjectIdentifier {
  ObjectIdentifier(key: String, version_id: Option(String))
}

pub type Deleted {
  Deleted(key: String, version_id: String)
}

pub fn request(
  bucket: String,
  objects: List(ObjectIdentifier),
) -> RequestBuilder {
  RequestBuilder(bucket:, objects:)
}

pub fn build(builder: RequestBuilder, creds: Credentials) -> Request(BitArray) {
  let body =
    xmb.x(
      "Delete",
      [#("xmlns", "http://s3.amazonaws.com/doc/2006-03-01/")],
      list.map(builder.objects, fn(object) {
        let children = [xmb.x("Key", [], [xmb.text(object.key)])]
        let children = case object.version_id {
          option.Some(id) -> [
            xmb.x("VersionId", [], [xmb.text(id)]),
            ..children
          ]
          option.None -> children
        }
        xmb.x("Object", [], children)
      }),
    )
    |> list.wrap
    |> xmb.render
    |> string_tree.to_string
    |> bit_array.from_string
  let query = [#("delete", option.Some(""))]
  let headers = [
    #(
      "content-md5",
      bit_array.base64_encode(crypto.hash(crypto.Md5, body), True),
    ),
  ]
  internal.request(
    creds,
    http.Post,
    "/" <> builder.bucket,
    query,
    headers,
    body,
  )
}

pub fn response(
  response: Response(BitArray),
) -> Result(List(Result(Deleted, ErrorObject)), BucketError) {
  case response.status {
    200 -> response_success(response)
    _ -> internal.s3_error(response)
  }
}

fn response_success(
  response: Response(BitArray),
) -> Result(List(Result(Deleted, ErrorObject)), BucketError) {
  let deleted =
    xml.element("Deleted", Deleted("", ""))
    |> xml.keep_text("Key", fn(a, e) { Deleted(..a, key: e) })
    |> xml.keep_text("VersionId", fn(a, e) { Deleted(..a, key: e) })

  xml.element("DeleteResult", [])
  |> xml.keep(deleted, fn(a, e) { [Ok(e), ..a] })
  |> xml.keep(internal.error_object(), fn(a, e) { [Error(e), ..a] })
  |> xml.parse(response.body)
  |> result.map(list.reverse)
}
