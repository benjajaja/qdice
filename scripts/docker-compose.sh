#!/usr/bin/env sh
set -e

export $(cat .env | xargs)
export $(cat .local_env | xargs)

docker-compose down -v
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d --remove-orphans

