#!/usr/bin/env sh

set -e

rsync -az --force --delete --progress --exclude-from=rsync_exclude.txt -e "ssh -p22 " ./ gipsy@qdice.wtf:/home/gipsy/nodice

ssh gipsy@qdice.wtf <<'ENDSSH'
set -e
cd nodice
./scripts/restart.sh
docker image prune -f &
echo goodbye
ENDSSH

echo "goodbye"
