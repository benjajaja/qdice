#!/bin/bash

docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
sleep 1
docker-compose stop nodice
./local_env.sh
