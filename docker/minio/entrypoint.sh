#!/bin/bash
# see https://docs.docker.com/engine/reference/builder/#entrypoint
set -e

# Initialize a default bucket
mkdir -p "$DATA_DIR/$BUCKET"

# Pass the Docker CMD to the image's original entrypoint script.
exec su -c "/usr/bin/docker-entrypoint.sh $*"
