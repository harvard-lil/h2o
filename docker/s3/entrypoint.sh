#!/bin/sh
# Create the buckets, then start the gateway.
# With the posix backend, a bucket is a top-level directory under
# $VGW_BACKEND_ARG, so creating the directory creates the bucket.
set -e

mkdir -p "$VGW_BACKEND_ARG/$BUCKET"
mkdir -p "$VGW_BACKEND_ARG/$EXPORT_BUCKET"
mkdir -p "$VGW_BACKEND_ARG/$PDF_EXPORT_BUCKET"

# The image's own entrypoint builds the versitygw command line from VGW_* variables.
exec /usr/local/bin/docker-entrypoint.sh "$@"
