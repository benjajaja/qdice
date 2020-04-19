#!/bin/bash
set -e

docker-compose build

./scripts/toast.sh "Server is restarting for an update..." || true
docker-compose stop nodice nginx telegram
docker-compose rm --force -v nodice nginx telegram
docker-compose -p $(basename $(pwd)) up -d --remove-orphans
