import bucket.{type Credentials}
import gleam/bit_array
import gleam/crypto
import gleam/http
import gleam/int
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleam/uri

/// A builder for creating S3 presigned URLs.
/// Presigned URLs allow you to grant temporary access to specific S3 objects
/// without sharing your secret credentials.
pub type PresignBuilder {
  PresignBuilder(
    bucket: String,
    key: String,
    expires_in: Int,
    method: http.Method,
  )
}

/// Create a new builder for a presigned GET request.
/// This is typically used to allow a browser or client to download a private file.
/// Default expiration is 3600 seconds (1 hour).
pub fn get_object(bucket: String, key: String) -> PresignBuilder {
  PresignBuilder(bucket:, key:, expires_in: 3600, method: http.Get)
}

/// Create a new builder for a presigned PUT request.
/// This allows a client to upload a file directly to your S3 bucket.
pub fn put_object(bucket: String, key: String) -> PresignBuilder {
  PresignBuilder(..get_object(bucket, key), method: http.Put)
}

/// Set the expiration time for the presigned URL in seconds.
/// Maximum allowed by AWS is usually 604800 (7 days).
pub fn expires_in(builder: PresignBuilder, seconds: Int) -> PresignBuilder {
  PresignBuilder(..builder, expires_in: seconds)
}

/// Generates the final presigned URL string using AWS Signature Version 4.
/// This process involves:
/// 1. Building a canonical request.
/// 2. Creating a string to sign.
/// 3. Deriving a signing key from the credentials.
/// 4. Calculating the HMAC-SHA256 signature and appending it to the query string.
pub fn build(builder: PresignBuilder, creds: Credentials) -> String {
  let datetime = now()
  let date = format_date(datetime)
  let timestamp = format_timestamp(datetime)

  let scope = string.join([date, creds.region, "s3", "aws4_request"], "/")

  // For presigned URLs, authentication parameters are passed as query strings
  let query_params = [
    #("X-Amz-Algorithm", "AWS4-HMAC-SHA256"),
    #("X-Amz-Credential", creds.access_key_id <> "/" <> scope),
    #("X-Amz-Date", timestamp),
    #("X-Amz-Expires", int.to_string(builder.expires_in)),
    #("X-Amz-SignedHeaders", "host"),
  ]

  let query_params = case creds.session_token {
    Some(token) -> list.append(query_params, [#("X-Amz-Security-Token", token)])
    None -> query_params
  }

  // Presigned URLs usually use 'UNSIGNED-PAYLOAD' because the body 
  // isn't known at the time of URL generation (especially for PUTs).
  let payload_hash = "UNSIGNED-PAYLOAD"

  let path = "/" <> builder.bucket <> "/" <> builder.key
  let host = case creds.port {
    Some(p) -> creds.host <> ":" <> int.to_string(p)
    None -> creds.host
  }

  // 1. Create Canonical Request
  let canonical_query =
    query_params
    |> list.sort(fn(a, b) { string.compare(a.0, b.0) })
    |> list.map(fn(pair) { pair.0 <> "=" <> uri.percent_encode(pair.1) })
    |> string.join("&")

  let canonical_request =
    string.uppercase(http.method_to_string(builder.method))
    <> "\n"
    <> path
    <> "\n"
    <> canonical_query
    <> "\n"
    <> "host:"
    <> host
    <> "\n\n"
    <> "host\n"
    <> payload_hash

  // 2. Create String to Sign
  let string_to_sign =
    "AWS4-HMAC-SHA256\n"
    <> timestamp
    <> "\n"
    <> scope
    <> "\n"
    <> string.lowercase(
      bit_array.base16_encode(
        crypto.hash(crypto.Sha256, <<canonical_request:utf8>>),
      ),
    )

  // 3. Calculate Signature
  let signature =
    derive_signing_key(creds.secret_access_key, date, creds.region, "s3")
    |> crypto.hmac(<<string_to_sign:utf8>>, crypto.Sha256, _)
    |> bit_array.base16_encode
    |> string.lowercase

  let scheme = case creds.scheme {
    http.Https -> "https"
    http.Http -> "http"
  }

  // 4. Construct URL
  scheme
  <> "://"
  <> host
  <> path
  <> "?"
  <> canonical_query
  <> "&X-Amz-Signature="
  <> signature
}

// --- Internal Helper Functions ---

/// Derives a signing key using a sequence of HMAC-SHA256 hashes.
fn derive_signing_key(
  secret: String,
  date: String,
  region: String,
  service: String,
) -> BitArray {
  <<"AWS4":utf8, secret:utf8>>
  |> crypto.hmac(<<date:utf8>>, crypto.Sha256, _)
  |> crypto.hmac(<<region:utf8>>, crypto.Sha256, _)
  |> crypto.hmac(<<service:utf8>>, crypto.Sha256, _)
  |> crypto.hmac(<<"aws4_request":utf8>>, crypto.Sha256, _)
}

/// Formats a date tuple as YYYYMMDD.
fn format_date(dt: #(#(Int, Int, Int), #(Int, Int, Int))) -> String {
  let #(#(y, m, d), _) = dt
  int.to_string(y) |> string.pad_start(4, "0")
  <> int.to_string(m) |> string.pad_start(2, "0")
  <> int.to_string(d) |> string.pad_start(2, "0")
}

/// Formats a full timestamp as YYYYMMDDTHHMMSSZ.
fn format_timestamp(dt: #(#(Int, Int, Int), #(Int, Int, Int))) -> String {
  let #(_, #(h, mi, s)) = dt
  format_date(dt)
  <> "T"
  <> int.to_string(h) |> string.pad_start(2, "0")
  <> int.to_string(mi) |> string.pad_start(2, "0")
  <> int.to_string(s) |> string.pad_start(2, "0")
  <> "Z"
}

@external(erlang, "os", "system_time")
fn system_time(unit: Int) -> Int

@external(erlang, "calendar", "system_time_to_universal_time")
fn system_time_to_universal_time(
  time: Int,
  unit: Int,
) -> #(#(Int, Int, Int), #(Int, Int, Int))

/// Returns the current UTC time.
fn now() -> #(#(Int, Int, Int), #(Int, Int, Int)) {
  system_time(1000) |> system_time_to_universal_time(1000)
}
