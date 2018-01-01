#!/bin/bash

rsync -az --force --delete --progress --iconv=utf-8-mac,utf-8 --exclude-from=rsync_exclude.txt -e "ssh -p22 " ./ gipsy@quevic.io:/home/gipsy/nodice

if [ $1 = "main" ]; then
ssh -tt gipsy@quevic.io <<'ENDSSH'
cd nodice
yarn
sleep 1
pm2 startOrReload ecosystem.config.js --env production --only main
ENDSSH

else 
ssh -tt gipsy@quevic.io <<'ENDSSH'
cd nodice
yarn
sleep 1
pm2 startOrReload ecosystem.config.js --env production
exit
ENDSSH
fi
