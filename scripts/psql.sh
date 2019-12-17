#!/bin/bash

docker run -it --rm --network qdice nodice_postgres psql -U bgrosse -h postgres -d nodice
