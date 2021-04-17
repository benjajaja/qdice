#!/bin/bash -e

if [ -d ~/nodice ]; then
  cd ~/nodice
else
  cd ~/o/qdice
fi
export $(cat .env | xargs)
export $(cat .local_env | xargs)

DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

docker run -i --rm --network qdice -e PGPASSWORD=$POSTGRES_PASSWORD postgres:9.6 \
  pg_dump -U bgrosse -h postgres -d nodice \
  -Z 9 | aws s3 cp - s3://qdice-postgres/backup_${DATE}.dump.gz
echo "Streamed DB archive to S3: backup_${DATE}.dump.gz"

DIR="/mnt/backups/backup_${DATE}"
FILENAME="files_${DATE}.tgz"
FILE_PATH="${DIR}/${FILENAME}"


mkdir -p $DIR
if [ -d ~/nodice ]; then
  cp -R /avatars/ $DIR
else
  cp -R ~/data-avatars/ $DIR
fi
cp -R data/logs/nginx/ $DIR


tar czf $FILE_PATH $DIR

aws s3 cp $FILE_PATH "s3://qdice-postgres/${FILENAME}"

echo "Uploaded avatars+logs to S3 bucket."

rm $FILE_PATH
rm -rf $DIR

echo "Deleted temporary files."
