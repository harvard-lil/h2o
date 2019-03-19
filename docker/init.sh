#!/usr/bin/env bash
set -e

docker-compose exec web rails sunspot:solr:start
docker-compose exec web rails db:setup
docker-compose exec web rails sunspot:solr:stop
