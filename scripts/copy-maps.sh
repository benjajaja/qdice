#!/bin/bash

rm -rf maps/*
for filename in ../edice/src/Maps/*.elm; do
  name="$(basename "$filename" .elm)"
  target="maps/${name}.emoji"
  echo "${filename} -> ${target}"
  cat $filename | sed -e '1,/"""/d' | sed -n '/"""/q;p' > $target
  ls maps
done
