#!/bin/bash

docker build --tag bgrosse/qdice:latest --build-arg build_id=$(git rev-parse HEAD) --build-arg git_log="$(git log --pretty=format:%s)" .

