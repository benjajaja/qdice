#!/bin/bash
set -e

./scripts/build.sh
./scripts/build.frontend.sh local

docker-compose down -v
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

cd e2e
yarn
# sleep 20 # emqx reports as started to docker, but has some internal delay
yarn test
cd ..

./scripts/build.frontend.sh production
docker push bgrosse/qdice:frontend-production
docker push bgrosse/qdice:backend

./scripts/deploy.sh
