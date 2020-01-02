FROM node:10.15.3-alpine
ARG build_id
ARG git_log

WORKDIR /usr/src/edice
COPY edice/package.json .
COPY edice/yarn.lock .
COPY edice/elm.json .
COPY edice/package.json .
COPY edice/webpack.config.js .
COPY edice/yarn.lock .
COPY edice/html ./html
COPY edice/maps ./maps
COPY edice/scripts ./scripts
COPY edice/src ./src

WORKDIR /usr/src/nodice
COPY package.json .
COPY yarn.lock .
COPY *.ts *.js *.json start.sh ./
COPY scripts ./scripts
COPY table ./table
COPY test ./test

WORKDIR /usr/src/edice
ENV git_log=$git_log
ENV build_id=$build_id
RUN yarn install --frozen-lockfile --production
RUN yarn generate-changelog
RUN yarn generate-maps
RUN yarn build
RUN rm -rf node_modules src html scripts package.json yarn.lock elm.json webpack.config.js

WORKDIR /usr/src/nodice
RUN apk add --update postgresql-dev
RUN apk add --update --no-cache --virtual .gyp python make g++
RUN yarn install --frozen-lockfile --production
RUN apk del .gyp
RUN node scripts/build.js /usr/src/edice/maps

EXPOSE 5001
CMD ["node", "server.js"]
