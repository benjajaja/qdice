FROM node:10.15.3

WORKDIR /usr/src/edice
COPY package.json .
COPY yarn.lock .
RUN yarn install || echo "spooky!"
COPY . .

RUN node ./scripts/generate-maps.js
RUN yarn build
