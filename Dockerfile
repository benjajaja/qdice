# node.js server build

FROM node:10.15.3-alpine AS server

WORKDIR /usr/src/nodice
COPY package.json .
COPY yarn.lock .
RUN yarn install --frozen-lockfile --production

COPY scripts ./scripts
COPY edice/maps ./edice/maps
COPY tsconfig.json ./
RUN node scripts/build.js edice/maps

COPY *.ts *.js ./
COPY table ./table
COPY test ./test
RUN yarn test --color false
# RUN node server.js --quit

# starting positions generation

FROM python:3 AS starting_positions

WORKDIR /starting_positions
COPY starting_positions/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY ./starting_positions/src ./src/

ENV PYTHONPATH=/starting_positions
COPY --from=server /usr/src/nodice/map-sources.json /starting_positions/maps/map-sources.json
RUN python ./src/generate_starting_positions.py --adj_mat_source ./maps/map-sources.json --out_dir /starting_positions/output/

# node.js server image run

FROM server

COPY --from=starting_positions /starting_positions/output /usr/src/nodice/starting_positions/maps/output

WORKDIR /usr/src/nodice
EXPOSE 5001
CMD ["node", "server.js"]

