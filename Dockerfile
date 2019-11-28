FROM node:10.15.3

WORKDIR /usr/src/edice
COPY edice/package.json .
COPY edice/yarn.lock .
RUN yarn install
COPY edice/. .
RUN yarn generate-maps
RUN yarn build

WORKDIR /usr/src/nodice
COPY package.json .
COPY yarn.lock .
RUN yarn install --frozen-lockfile
COPY *.ts *.js *.json ./
COPY scripts ./scripts
COPY table ./table
RUN node scripts/build.js /usr/src/edice/maps

EXPOSE 5001
CMD ["node", "server.js"]
