FROM node:10.15.3
ARG build_id

WORKDIR /usr/src/edice
COPY edice/package.json .
COPY edice/yarn.lock .
RUN yarn install
COPY edice/. .
RUN yarn generate-maps
ENV build_id=$build_id
RUN yarn build

WORKDIR /usr/src/nodice
COPY package.json .
COPY yarn.lock .
RUN yarn install --frozen-lockfile
COPY *.ts *.js *.json start.sh ./
COPY scripts ./scripts
COPY table ./table
RUN node scripts/build.js /usr/src/edice/maps

EXPOSE 5001
CMD ["sh", "start.sh"]
