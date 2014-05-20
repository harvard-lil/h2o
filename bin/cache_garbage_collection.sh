#!/bin/sh

# Note: possibly hard code directory to ensure correct directory is deleted from
# Note: possibly rm -rf if we want to force directory purges
find ../tmp/cache/* -mtime +14 -exec rm {} \;
