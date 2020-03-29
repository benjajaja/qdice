#!/bin/bash
set -e

docker-compose build --no-cache

docker-compose stop nodice nginx telegram
docker-compose rm --force -v nodice nginx
docker-compose -p $(basename $(pwd)) up -d --remove-orphans

