#!/bin/bash
export $(cat .env | xargs)
export $(cat .local_env | xargs)
node server.js
