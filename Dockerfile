# node.js server build

FROM node:12.14.1-alpine AS server
ENV NODE_ENV=production

WORKDIR /usr/src/nodice
COPY package.json .
COPY yarn.lock .
RUN yarn install --frozen-lockfile --production

COPY edice/scripts/generate-maps.js ./scripts/generate-maps.js
COPY edice/maps ./edice/maps
RUN node ./scripts/generate-maps.js ./edice/maps/

COPY tsconfig.json ./
COPY *.ts *.js ./
COPY table ./table
COPY test ./test
RUN yarn test --color false

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

ARG build_id
COPY scripts/write-version.ts ./scripts/write-version.ts
RUN yarn ts-node scripts/write-version.ts $build_id


WORKDIR /usr/src/nodice
EXPOSE 5001
CMD ["yarn", "ts-node", "main.ts"]

