FROM node:10.15.3-alpine
ARG build_id
ARG git_log

WORKDIR /usr/src/edice
COPY package.json yarn.lock ./
ENV NODE_ENV=production
RUN yarn install --frozen-lockfile --production

COPY elm.json webpack.config.js ./
COPY html ./html
COPY maps ./maps
COPY scripts ./scripts
COPY src ./src

ENV git_log=$git_log
ENV build_id=$build_id
RUN yarn generate-changelog
RUN yarn generate-maps
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

