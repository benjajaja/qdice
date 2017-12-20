#!/bin/bash

rsync -az --force --delete --progress --iconv=utf-8-mac,utf-8 --exclude-from=rsync_exclude.txt -e "ssh -p22 " ./ gipsy@quedice.host:/home/gipsy/nodice

ssh -tt gipsy@quedice.host <<'ENDSSH'
cd nodice
yarn
pm2 startOrRestart ecosystem.config.js --env production
exit
ENDSSH
