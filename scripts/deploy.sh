#!/bin/bash

rsync -az --force --delete --progress --exclude-from=rsync_exclude.txt -e "ssh -p22 " ./ gipsy@qdice.wtf:/home/gipsy/nodice2 || exit 1

ssh -tt gipsy@qdice.wtf <<'ENDSSH'
cd nodice2
docker-compose down --volumes
docker-compose pull nodice
docker-compose up -d --force-recreate --remove-orphans
exit 0
ENDSSH
