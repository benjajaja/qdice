#!/bin/bash
set -e

docker-compose build

docker-compose stop nodice nginx telegram
docker-compose rm --force -v nodice nginx telegram
docker-compose -p $(basename $(pwd)) up -d --remove-orphans

