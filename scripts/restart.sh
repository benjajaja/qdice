#!/bin/bash
set -e

docker-compose build

CONTAINERS="nodice nginx beancounter"
./scripts/toast.sh "Server is restarting for an update..." || true
[ ! -z "$CONTAINERS" ] && docker-compose stop $CONTAINERS
[ ! -z "$CONTAINERS" ] && docker-compose rm --force -v $CONTAINERS
docker-compose -p $(basename $(pwd)) up -d --remove-orphans
