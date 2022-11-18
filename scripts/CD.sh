#!/usr/bin/env sh
set -e

# ./scripts/CI.sh

./scripts/build.sh && \
./scripts/build.frontend.sh && \
docker push bgrosse/qdice:frontend && \
docker push bgrosse/qdice:backend && \
docker push bgrosse/qdice:beancounter && \
./scripts/deploy.sh
