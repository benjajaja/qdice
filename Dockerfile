FROM node:10.15.3-alpine
ARG build_id
ARG git_log

WORKDIR /usr/src/edice
COPY edice/package.json .
COPY edice/yarn.lock .
RUN yarn install
COPY edice/. .
COPY .git ../.git
ENV git_log=$git_log
RUN yarn generate-changelog
RUN rm -rf .git
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
CMD ["node", "server.js"]
