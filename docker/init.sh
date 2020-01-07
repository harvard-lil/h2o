#!/usr/bin/env bash
set -e

display_usage() {
    echo "Seed dev database with data from a pg_dump file."
    echo
    echo "Usage:"
    echo "  bash docker/init.sh -f dump_file"
}

# Help
if [[ ( $1 == "--help") ||  ($1 == "-h")]]; then
    display_usage
    exit 0
fi


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
    # wrong number of args
    display_usage
    exit 1
fi

echo "Loading data from $FILE ..."
docker cp "$FILE" "$(docker-compose ps -q db)":/tmp/data.dump
docker-compose exec db bash -c "pg_restore -l /tmp/data.dump | grep -v schema_migrations | grep -v ar_internal_metadata > /tmp/restore.list"
docker-compose exec db pg_restore -L /tmp/restore.list --disable-triggers --username=postgres --verbose --no-owner -h localhost -d postgres /tmp/data.dump
docker-compose exec db rm -f /tmp/data.dump /tmp/restore.list

