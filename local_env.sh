#!/bin/bash



# docker-compose up -d
# docker-compose stop nodice
#
# kitty -d ./edice --detach yarn start
# kitty -d . --detach docker-compose logs -f
# kitty -d . --hold --detach nv

export GOOGLE_OAUTH_SECRET="e8Nkmj9X05_hSrrREcRuDCFj"
export PORT=5001
export JWT_SECRET="dnauh23uasjdnlnalkslk1daWDEDasdd1madremia"
export MQTT_URL="mqtt://localhost:1883"
export MQTT_USERNAME="client"
export MQTT_PASSWORD="client"
export PGPORT="5433"
export PGHOST="localhost"
export PGUSER="bgrosse"
export PGDATABASE="nodice"
export API_ROOT="/api"

export BOT_TOKEN="423731161:AAGtwf2CmhOFOnwVocSwe0ylyh63zCyfzbo"
export BOT_GAME="QueDiceTest"
export BOT_OFFICIAL_GROUPS=""
export AVATAR_PATH="/Users/bgrosse/o/edice/html/pictures"
export PICTURE_URL_PREFIX="/pictures/"
export E2E="1"


node server.js

