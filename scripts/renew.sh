#!/bin/bash -e

if [ -d ~/nodice ]; then
  cd ~/nodice
else
  cd ~/o/qdice
fi
export $(cat .env | xargs)
export $(cat .local_env | xargs)

docker-compose -p $(basename $(pwd)) run certbot
docker-compose -p $(basename $(pwd)) restart nginx

