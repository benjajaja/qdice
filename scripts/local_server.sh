#!/bin/bash
docker-compose stop nodice &
export $(cat .env | xargs)
export $(cat .local_env | xargs)
TS_NODE_CACHE=false nodemon -e .ts main.ts
