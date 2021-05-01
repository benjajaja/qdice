#!/bin/bash

cd ~/nodice
docker-compose exec -T nodice node awards.js weekly
