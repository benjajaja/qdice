#!/bin/bash
export $(cat .env | xargs)
export $(cat .local_env | xargs)

docker run -it --rm --network qdice -e PGPASSWORD=$POSTGRES_PASSWORD $(basename $(pwd))_postgres \
  psql -U bgrosse -h postgres -d nodice
