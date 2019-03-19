#!/usr/bin/env bash
set -e

display_usage() {
    echo "Create dev and test databases. Dev database may optionally be seeded with data from a pg_dump file."
    echo
    echo "Usage:"
    echo "  bash docker/init.sh [-f dump_file]"
}

function stop_solr {
  echo "Stopping solr ..."  && docker-compose exec web rails sunspot:solr:stop
}

# Help
if [[ ( $1 == "--help") ||  ($1 == "-h")]]; then
    display_usage
    exit 0
fi

# Optional flag to use dump file
if [[ $# -gt 0 ]]; then
    getopts ":f:" opt || true;
    case $opt in
        f)
            if [ -f "$OPTARG" ]
            then
                FILE=$OPTARG
            else
                echo "Invalid path."
                exit 1
            fi
            ;;
        \?)
            # illegal option or argument
            display_usage
            exit 1
            ;;
        :)
            # -f present, but no path provided
            echo "Please specify the path."
            exit 1
            ;;
    esac
    if [[ $((OPTIND - $#)) -ne 1 ]]; then
        # too many args
        display_usage
        exit 1
    fi
fi

echo "Starting solr ..." && docker-compose exec web rails sunspot:solr:start
trap stop_solr EXIT

echo "Creating databases ..." && docker-compose exec web rails db:setup
if [ "$FILE" ]; then
    echo "Loading data from $FILE ..."
    docker cp $FILE "$(docker-compose ps -q db)":/tmp/data.dump
    # temporarily forcing the next line to return 0, until we understand
    # the key constraint errors we are getting ("WARNING: errors ignored on restore: 4")
    docker-compose exec db pg_restore --username=postgres --verbose --data-only --no-owner -h localhost -d h2o_dev /tmp/data.dump || true;
    docker-compose exec db rm -f /tmp/data.dump
    echo "Building solr index ..." && docker-compose exec web rails sunspot:solr:reindex
fi
