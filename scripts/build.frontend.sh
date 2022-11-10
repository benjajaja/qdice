#!/usr/bin/env sh
set -e

echo "Build frontend-${1:-"production"}"
docker build --tag bgrosse/qdice:frontend-${1:-"production"} \
  --build-arg build_id=$(git rev-parse HEAD) \
  --build-arg ENV=${1:-"production"} \
  ./edice

