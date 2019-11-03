#!/bin/bash

rsync -az --force --delete --progress --exclude-from=rsync_exclude.txt -e "ssh -p22 " ./ gipsy@qdice.wtf:/home/gipsy/nodice2

# ssh -tt gipsy@qdice.wtf <<'ENDSSH'
# cd nodice
# yarn
# sleep 1
# pm2 startOrReload ecosystem.config.js --env production
# ENDSSH
