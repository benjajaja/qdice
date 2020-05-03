FROM node:10.15.3-alpine

# node_modules
WORKDIR /usr/src/edice
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile --production
# install elm-test
RUN yarn global add elm-test@0.19.1-revision2 elm@0.19.1-3

# cache package.elm-lang.org
COPY src/Dummy.elm ./src/
COPY elm.json ./
RUN yarn elm make src/Dummy.elm

# maps
COPY maps ./maps
COPY scripts ./scripts
COPY html ./html
RUN yarn generate-maps

# run elm-test
COPY src ./src
COPY tests ./tests
RUN elm-test
RUN yarn global remove elm-test elm
RUN rm -rf ./tests

# build
COPY webpack.config.js ./
ENV NODE_ENV=production
ARG build_id
ENV build_id=$build_id
RUN yarn build --color false
RUN yarn test
RUN yarn gzip

# NGINX

FROM nginx:mainline
ARG ENV

WORKDIR /
COPY data/nginx/default.conf.${ENV} /etc/nginx/conf.d/default.conf
COPY data/nginx/proxy_params /etc/nginx/proxy_params
COPY data/nginx/.htpasswd /etc/nginx/.htpasswd

COPY --from=0 /usr/src/edice/dist /var/www/qdice.wtf

