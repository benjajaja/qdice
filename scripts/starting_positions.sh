#!/bin/bash

docker build --tag starting ./starting_positions

rm -rf starting_positions/maps
mkdir -p starting_positions/maps/adj_mat
mkdir -p starting_positions/maps/output
cp map-sources.json starting_positions/maps/

MAPS=""
for f in edice/maps/*
do
  NAME=$(head -n 1 $f)
  MAPS="${MAPS} ${NAME}"
done

echo $MAPS

docker run -e "MAPS=${MAPS}" -v "$(realpath starting_positions/maps):/app/maps" starting
echo "Starting positions have been built for: ${MAPS}"
