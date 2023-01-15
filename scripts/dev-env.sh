#!/usr/bin/env sh
export $(cat .env | xargs)
export $(cat .local_env | xargs)
# docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
