#!/usr/bin/env bash
set -e

function cleanup {
  docker-compose exec web rails sunspot:solr:stop
  docker-compose exec web rm -f tmp/pids/server.pid
}
trap cleanup EXIT

docker-compose exec web rm -f tmp/pids/server.pid
docker-compose exec web rails sunspot:solr:start
docker-compose exec web bundle exec rails s -p 8000 -b '0.0.0.0'
