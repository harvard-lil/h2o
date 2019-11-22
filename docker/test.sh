#!/usr/bin/env bash
set -e

function cleanup {
#  echo "Stopping solr ..."  && docker-compose exec web rails sunspot:solr:stop
}
trap cleanup EXIT

#echo "Starting solr ..."  && docker-compose exec web rails sunspot:solr:start
docker-compose exec web yarn test
docker-compose exec web rails test
docker-compose exec web rails test:system
