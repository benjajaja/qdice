#!/bin/bash

docker-compose build --no-cache
docker-compose stop nodice nginx telegram
docker-compose rm --force -v nodice nginx
docker volume rm nodice_statics
docker-compose -p $(basename $(pwd)) up -d --remove-orphans

