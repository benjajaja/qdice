#!/bin/bash

set -e

rsync -az --force --delete --progress --exclude-from=rsync_exclude.txt -e "ssh -p22 " ./ gipsy@qdice.wtf:/home/gipsy/nodice || exit 1

ssh -tt gipsy@qdice.wtf <<'ENDSSH'
cd nodice
docker-compose pull nodice
docker-compose build --no-cache
docker-compose stop nodice nginx telegram
docker-compose rm --force -v nodice nginx
docker volume rm nodice_statics
docker-compose up -d --remove-orphans
docker-compose restart telegram
exit 0
ENDSSH
