# FROM buildkite/puppeteer:latest
FROM zenato/puppeteer-renderer

WORKDIR /usr/src/e2e
COPY package.json .
COPY yarn.lock .
RUN yarn install
COPY . .

