#!/usr/bin/env sh
export $(cat .env | xargs)
export $(cat .local_env | xargs)

docker run -it --rm --network $(basename $(pwd))_default -e PGPASSWORD=$POSTGRES_PASSWORD postgres:9.6 \
  psql -U bgrosse -h qdice_postgres -d nodice
