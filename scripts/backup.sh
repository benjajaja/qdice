#!/bin/bash
export $(cat .env | xargs)
export $(cat .local_env | xargs)

DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
DIR="/tmp/backup_${DATE}"
FILENAME="backup_${DATE}.tgz"
FILE_PATH="/tmp/backup_${DATE}.tgz"


mkdir $DIR

docker run -it --rm --network qdice -e PGPASSWORD=$POSTGRES_PASSWORD nodice_postgres \
  pg_dump -U bgrosse -h postgres -d nodice \
  > $DIR/pg_dump.sql

echo "Created DB archive."

cp -R ~/data-avatars/ $DIR
cp -R data/logs/nginx/ $DIR


tar czf $FILE_PATH $DIR

aws2 glacier upload-archive --account-id - --vault-name qdice_postgres --body $FILE_PATH

echo "Uploaded DB to S3 Glacier."

aws2 s3 cp $FILE_PATH "s3://qdice-postgres/${FILENAME}"

echo "Uploaded DB to S3 bucket."

