#!/bin/bash
# see https://docs.docker.com/engine/reference/builder/#entrypoint
set -e

# Initialize a bucket for images
mkdir -p "$DATA_DIR/$BUCKET"

# Initialize a bucket for exports
mkdir -p "$DATA_DIR/$EXPORT_BUCKET"

# Initialize a bucket for PDF exports
mkdir -p "$DATA_DIR/$PDF_EXPORT_BUCKET"

# Pass the Docker CMD to the image's original entrypoint script.
exec su -c "/usr/bin/docker-entrypoint.sh $*"
