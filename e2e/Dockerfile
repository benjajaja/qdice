# FROM buildkite/puppeteer:latest
FROM zenato/puppeteer-renderer

WORKDIR /usr/src/e2e
COPY package.json yarn.lock .
RUN yarn install --frozen-lockfile --production

COPY . .

