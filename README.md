# bucket

Gleam S3 API client, suitable for AWS S3, Garage, Minio, Storj,
Backblaze B2, Cloudflare R2, Ceph, Wasabi, and so on!

[![Package Version](https://img.shields.io/hexpm/v/bucket)](https://hex.pm/packages/bucket)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/bucket/)

This package uses the _sans-io_ approach, meaning it does not send HTTP requests
itself, instead it gives you functions for creating HTTP requests for and
decoding HTTP responses from an S3 API, and you send the requests with a HTTP
client of your choosing.

This HTTP client independence gives you full control over HTTP, and means this
library can be used on both the Erlang and JavaScript runtimes.

```sh
gleam add bucket@1
```
```gleam
import bucket
import bucket/get_object.{Found}
import gleam/bit_array
import gleam/http.{Https}
import gleam/io
import httpc

/// This program downloads an object and prints the string contents.
///
/// It uses `let assert` to handle errors, but in a real program you'd most
/// likely want to use pattern matching or the `gleam/result` module to handle
/// the error values gracefully.
///
pub fn main() {
  let creds = bucket.credentials(
    base_url: "https://s3-api-host.example.com",
    access_key_id: "YOUR_ACCESS_KEY",
    secret_access_key: "YOUR_SECRET_ACCESS_KEY",
  )

  // Create a HTTP request to download an object
  let request =
    get_object.request(bucket: "my-bucket", key: "my/key.txt")
    |> get_object.build(creds)

  // Send the HTTP request
  let assert Ok(response) = httpc.send_bits(request)

  // Decode the response from the API
  let assert Ok(Found(object)) = get_object.response(response)

  // Print the string contents
  let assert Ok(text) = bit_array.to_string(object)
  io.println(text)
}
```

The following endpoints are supported:

- [CreateBucket](https://docs.aws.amazon.com/AmazonS3/latest/API/API_CreateBucket.html)
- [DeleteBucket](https://docs.aws.amazon.com/AmazonS3/latest/API/API_DeleteBucket.html)
- [DeleteObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_DeleteObject.html)
- [DeleteObjects](https://docs.aws.amazon.com/AmazonS3/latest/API/API_DeleteObjects.html)
- [GetObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html)
- [HeadBucket](https://docs.aws.amazon.com/AmazonS3/latest/API/API_HeadBucket.html)
- [HeadObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_HeadObject.html)
- [ListBuckets](https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListBuckets.html)
- [ListObjects](https://docs.aws.amazon.com/AmazonS3/latest/API/API_ListObjects.html)
- [PutObject](https://docs.aws.amazon.com/AmazonS3/latest/API/API_PutObject.html)
- [CreateMultipartUpload](https://docs.aws.amazon.com/AmazonS3/latest/API/API_CreateMultipartUpload.html)
- [UploadPart](https://docs.aws.amazon.com/AmazonS3/latest/API/API_UploadPart.html)
- [CompleteMultipartUpload](https://docs.aws.amazon.com/AmazonS3/latest/API/API_CompleteMultipartUpload.html)

Further documentation can be found at <https://hexdocs.pm/bucket>.
