#!/usr/bin/env sh
set -e 
set -x

yarn build

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/.."

mkdir -p electron
cd electron
rm -rf ./*
cd ..

cp -r electron.js preload.js dist/* electron/
cp electron_package.json electron/package.json
cp electron_yarn.lock electron/yarn.lock || true
cd electron
yarn
cp yarn.lock ../electron_yarn.lock
yarn electron-forge make --platform win32
yarn electron-forge make --platform linux

WORK_DIR=out/zipfix
mkdir -p $WORK_DIR
cd $WORK_DIR
rm -rf ./*

unzip $DIR/electron/out/make/zip/win32/x64/qdice-win32-x64-0.0.1.zip
cd qdice-win32-x64
zip -r $DIR/electron/out/qdice_steam_win32.zip *

unzip $DIR/electron/out/make/zip/linux/x64/qdice-linux-x64-0.0.1.zip
cd qdice-linux-x64
zip -r $DIR/electron/out/qdice_steam_linux.zip *

