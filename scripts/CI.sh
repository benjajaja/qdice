#!/bin/bash
set -e

./scripts/unit_tests.sh

./scripts/build.sh


./scripts/restart.sh

cd e2e
yarn test
cd ..

docker push bgrosse/qdice:latest

# docker build ./e2e -t qdice2e
# docker network create qdice || true
# docker run --network qdice -e E2E_URL=http://nginx qdice2e yarn test

./scripts/deploy.sh
