#!/bin/bash

docker-compose build --no-cache
docker-compose stop nodice nginx telegram
docker-compose rm --force -v nodice nginx
docker volume rm nodice_statics
docker-compose up -d --remove-orphans
docker-compose -p nodice up -d
docker-compose restart telegram

