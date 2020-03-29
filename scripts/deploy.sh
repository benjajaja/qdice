#!/bin/bash

set -e

rsync -az --force --delete --progress --exclude-from=rsync_exclude.txt -e "ssh -p22 " ./ gipsy@qdice.wtf:/home/gipsy/nodice || exit 1

ssh -tt gipsy@qdice.wtf <<'ENDSSH'
set -e
cd nodice
docker-compose pull nodice
./scripts/restart.sh
docker image prune -f &
exit 0
ENDSSH
