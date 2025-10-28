#!/bin/sh
# POSIX-compatible script used by createbuckets service
# Idempotent: recreates buckets

# Don't use pipefail (not POSIX in some /bin/sh)
set -eu

echo "mc version:"
mc --version || true

echo "Waiting for MinIO and configuring alias..."

RETRIES=0
until mc alias set minio http://minio:9000 minioautumn minioautumn >/dev/null 2>&1
do
  RETRIES=$((RETRIES + 1))
  echo "mc alias set failed (attempt ${RETRIES}). Sleeping 1s..."
  sleep 1
done

echo "MinIO alias set succeeded"

BUCKETS="attachments avatars backgrounds icons banners emojis"

for b in $BUCKETS; do
  echo "Ensuring bucket: ${b}"
  mc rm -r --force minio/${b} >/dev/null 2>&1 || true
  mc mb --ignore-existing minio/${b} || true
  mc policy set public minio/${b} || true
done

echo "Buckets configured; exiting."
exit 0

