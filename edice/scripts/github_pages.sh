#!/bin/bash

yarn build
SHA1=$(git rev-list -n 1 HEAD)
cd dist
git commit -a -m "Update gh-pages from ${SHA1}"
git push
cd ..
