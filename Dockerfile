FROM node:9.2.1

WORKDIR /usr/src/nodice
COPY package.json .
COPY yarn.lock .
RUN yarn install
COPY . .

EXPOSE 5001

CMD ["node", "server.js"]
