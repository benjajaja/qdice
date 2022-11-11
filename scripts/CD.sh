#!/usr/bin/env sh
set -e

# ./scripts/CI.sh

./scripts/build.sh production && \
./scripts/build.frontend.sh production && \
docker push bgrosse/qdice:frontend-production && \
docker push bgrosse/qdice:backend && \
docker push bgrosse/qdice:beancounter && \
./scripts/deploy.sh
