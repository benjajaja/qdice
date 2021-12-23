#!/bin/bash
export $(cat .env | xargs)
export $(cat .local_env | xargs)

docker run -it --rm --network qdice_default -e PGPASSWORD=$POSTGRES_PASSWORD postgres:9.6 \
  psql -U bgrosse -h qdice_postgres -d nodice
