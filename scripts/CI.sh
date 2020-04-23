#!/bin/bash
set -e

./scripts/build.sh
./scripts/build.frontend.sh local

./scripts/docker-compose.sh

cd e2e
yarn
# sleep 20 # emqx reports as started to docker, but has some internal delay
yarn test
cd ..


