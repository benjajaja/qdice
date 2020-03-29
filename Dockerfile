WORKDIR /usr/src/nodice
COPY package.json .
COPY yarn.lock .
COPY *.ts *.js *.json start.sh ./
COPY scripts ./scripts
COPY table ./table
COPY test ./test
COPY starting_positions/maps/ ./starting_positions/maps/

RUN yarn install --frozen-lockfile --production
RUN node scripts/build.js /usr/src/edice/maps

EXPOSE 5001
CMD ["node", "server.js"]
