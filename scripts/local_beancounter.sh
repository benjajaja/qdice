#!/bin/bash
docker-compose stop beancounter &
export $(cat .env | xargs) 
export $(cat .local_env | xargs)
nodemon -e .ts beancounter.ts
