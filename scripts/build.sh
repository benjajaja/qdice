#!/bin/bash


docker-compose build --no-cache

./scripts/starting_positions.sh
docker build --tag bgrosse/qdice:latest --build-arg build_id=$(git rev-parse HEAD) --build-arg git_log="$(git log --pretty=format:%ad%n%h%n%s%n%b---)" .

