#!/bin/bash

path=$1

if [ -d ~/nodice ]; then
  cd ~/nodice
else
  cd ~/o/qdice
fi
export $(cat .env | xargs)
export $(cat .local_env | xargs)

# docker run -ti --rm --network qdice -e PGPASSWORD=$POSTGRES_PASSWORD qdice_postgres \
  # psql -U bgrosse -h postgres -d nodice

cat <<EOF | docker run -i --rm --network qdice -e PGPASSWORD=$POSTGRES_PASSWORD qdice_postgres \
  psql -U bgrosse -h postgres -d nodice
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO public;
EOF

cat $path | docker run -i --rm --network qdice -e PGPASSWORD=$POSTGRES_PASSWORD qdice_postgres \
  psql -U bgrosse -h postgres -d nodice
