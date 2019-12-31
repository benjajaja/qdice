#!/bin/bash

cd ~/nodice
docker-compose exec nodice node awards.js monthly
