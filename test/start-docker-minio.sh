docker run -d --rm --name bucket-minio \
  -p 9000:9000 \
  -p 9001:9001 \
  -e "MINIO_ROOT_USER=minioadmin" \
  -e "MINIO_ROOT_PASSWORD=miniopass" \
  -v ./test/create-buckets.sh:/usr/local/bin/create-buckets.sh \
  minio/minio server /data
