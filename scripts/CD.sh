#!/bin/bash
set -e

./scripts/CI.sh

./scripts/build.frontend.sh production
docker push bgrosse/qdice:frontend-production
docker push bgrosse/qdice:backend
./scripts/deploy.sh
