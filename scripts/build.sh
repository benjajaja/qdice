#!/usr/bin/env sh
set -e

docker build \
  --tag bgrosse/qdice:backend \
  --build-arg build_id=$(git rev-parse HEAD) \
  .

docker build --tag bgrosse/qdice:beancounter -f Dockerfile.beancounter .
