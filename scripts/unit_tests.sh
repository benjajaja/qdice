#!/bin/bash

cd edice
yarn generate-maps
git_log="dummy" yarn generate-changelog
yarn build
yarn test

cd ..
yarn generate-maps
yarn test
