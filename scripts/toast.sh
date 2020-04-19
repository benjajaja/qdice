#!/bin/bash
export $(cat .env | xargs)
export $(cat .local_env | xargs)

node toast.js $*
# docker run -it --rm --network qdice --env-file .env $(basename $(pwd))_nodice \
  # psql -U bgrosse -h postgres -d nodice
