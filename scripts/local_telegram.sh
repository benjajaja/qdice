#!/bin/bash
docker-compose stop telegram &
export $(cat .env | xargs) 
export $(cat .local_env | xargs)
node telegram.js
