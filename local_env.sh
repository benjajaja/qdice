#!/bin/bash
docker-compose stop nodice &
export $(cat .env | xargs)
export $(cat .local_env | xargs)
node server.js
