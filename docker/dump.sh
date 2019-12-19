#!/usr/bin/env bash
set -e

display_usage() {
    echo "Dump dev database to a file, analogous to our production backup."
    echo
    echo "Usage:"
    echo "  bash docker/dump.sh [-f dump_file]"
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

echo "Dumping database ..."
if [ ! "$FILE" ]; then
    FILE=h2o_dev-$(date +"%Y%m%d%H%M%S").dump
fi
echo "Writing data to $FILE ..."
docker-compose exec db pg_dump -Fc postgres -h localhost -U postgres -w -f /tmp/data.dump
docker cp "$(docker-compose ps -q db)":/tmp/data.dump $FILE
docker-compose exec db rm -f /tmp/data.dump
