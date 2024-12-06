#!/bin/bash
set -e

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "Not running as root"
    exit
fi

docker-compose pull
docker-compose up --force-recreate --build -d
docker image prune -f
