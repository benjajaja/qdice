#!/bin/bash
set -e

docker build --tag bgrosse/qdice:emqx ./data/emqx
docker build \
  --tag bgrosse/qdice:backend \
  --build-arg git_log="$(git log --pretty=format:%ad%n%h%n%s%n%b---)" \
  --build-arg build_id=$(git rev-parse HEAD) \
  .

