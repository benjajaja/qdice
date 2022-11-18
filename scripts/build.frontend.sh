#!/usr/bin/env sh
set -e

echo "Build frontend"
docker build --tag bgrosse/qdice:frontend \
  --build-arg build_id=$(git rev-parse HEAD) \
  ./edice

