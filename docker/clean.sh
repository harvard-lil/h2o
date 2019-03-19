#!/usr/bin/env bash

docker-compose down --remove-orphans --rmi all --volumes
rm -f tmp/pids/server.pid
rm -rf solr/data
