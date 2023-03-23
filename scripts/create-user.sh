#!/usr/bin/env sh
set -e

export $(cat .env | xargs)
export $(cat .local_env | xargs)

yarn ts-node create-user.ts "$@"
