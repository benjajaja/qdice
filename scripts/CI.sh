#!/bin/bash
set -e

./scripts/build.sh

./scripts/restart.sh

cd e2e
yarn
sleep 15 # emqx reports as started to docker, but has some internal delay
yarn test
cd ..

docker push bgrosse/qdice:latest

# docker build ./e2e -t qdice2e
# docker network create qdice || true
# docker run --network qdice -e E2E_URL=http://nginx qdice2e yarn test

./scripts/deploy.sh
