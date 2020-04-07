#!/bin/bash
set -e

echo "Build frontend-${1:-"production"}"
docker build --tag bgrosse/qdice:frontend-${1:-"production"} \
  --build-arg build_id=$(git rev-parse HEAD) \
  --build-arg git_log="$(git log --pretty=format:%ad%n%h%n%s%n%b---)" \
  --build-arg ENV=${1:-"production"} \
  ./edice

