#!/bin/bash
set -e

docker build --tag bgrosse/qdice:emqx ./data/emqx
docker build \
  --tag bgrosse/qdice:backend \
  --build-arg build_id=$(git rev-parse HEAD) \
  .

