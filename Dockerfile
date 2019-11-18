FROM nginx:mainline
ARG ENV

RUN apt-get update && apt-get install -y \
  curl \
  python \
  make \
  g++

RUN curl -sL https://deb.nodesource.com/setup_10.x | bash -
RUN apt-get update && apt-get install -y nodejs
# RUN curl -o- -L https://yarnpkg.com/install.sh | bash
RUN npm install -g yarn

WORKDIR /usr/src/edice
COPY package.json .
COPY yarn.lock .
RUN yarn install
COPY . .


RUN node ./scripts/generate-maps.js
RUN yarn build

WORKDIR /
RUN cp -r /usr/src/edice/nginx/default.conf.$ENV /etc/nginx/conf.d/default.conf
RUN cp -r /usr/src/edice/nginx/proxy_params /etc/nginx/proxy_params
RUN mkdir -p /var/www
RUN rm -rf /var/www/qdice.wtf
RUN cp -r /usr/src/edice/dist /var/www/qdice.wtf

