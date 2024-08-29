import bucket.{type Credentials, type S3Error}
import bucket/internal
import gleam/bit_array
import gleam/http
import gleam/http/request.{type Request, Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/option.{type Option}
import gleam/string_builder
import xmb

pub type RequestBuilder {
  RequestBuilder(name: String, region: Option(String))
}

pub fn request(name name: String) -> RequestBuilder {
  RequestBuilder(name:, region: option.None)
}

/// The region to create the bucket in. Defaults to the region from the
/// credentials if no region is specifier.
///
pub fn region(builder: RequestBuilder, region: String) -> RequestBuilder {
  RequestBuilder(..builder, region: option.Some(region))
}

pub fn build(builder: RequestBuilder, creds: Credentials) -> Request(BitArray) {
  let body =
    xmb.x(
      "CreateBucketConfiguration",
      [#("xmlns", "http://s3.amazonaws.com/doc/2006-03-01/")],
      [
        xmb.x("LocationConstraint", [], [
          xmb.text(option.unwrap(builder.region, creds.region)),
        ]),
      ],
    )
    |> xmb.render_fragment
    |> string_builder.to_string
    |> bit_array.from_string
  internal.request(creds, http.Put, "/" <> builder.name, body)
}

pub fn response(response: Response(BitArray)) -> Result(Nil, S3Error) {
  case response.status {
    200 -> Ok(Nil)
    419 -> todo as "one of the listed errors"
    x -> todo as { "unexpected error " <> int.to_string(x) }
  }
}
