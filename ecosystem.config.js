const tableConfig = require('./tables.config');

const env_production = {
  NODE_ENV: 'production',
  GOOGLE_OAUTH_SECRET: 'e8Nkmj9X05_hSrrREcRuDCFj',
  PORT: 5001,
  JWT_SECRET: 'dnauh23uasjdnlnalkslk1daWDEDasdd1madremia',
  MQTT_URL: 'mqtt://localhost:11883',
  MQTT_USERNAME: 'nodice',
  MQTT_PASSWORD: 'PeyY9TYap2vaZxQ8tTMXcD57',
  PGUSER: 'gipsy',
  PGPASSWORD: '>SKBHS^$dS*7M<P^UkpL]Yb<L',
  PGDATABASE: 'nodice',
  BOT_TOKEN: '478186891:AAF8m2BYVGF92p0L1oeCUOquvgF6ajLEvxc',
  BOT_GAME: 'QueDice',
  BOT_OFFICIAL_GROUPS: '-286837303',
  AVATAR_PATH: '/var/www/quevic.io/pictures',
  PICTURE_URL_PREFIX: 'https://quevic.io/pictures/',
};
const env_local = {
  GOOGLE_OAUTH_SECRET: 'e8Nkmj9X05_hSrrREcRuDCFj',
  PORT: 5001,
  JWT_SECRET: 'dnauh23uasjdnlnalkslk1daWDEDasdd1madremia',
  MQTT_URL: 'mqtt://localhost:11883',
  MQTT_USERNAME: 'client',
  MQTT_PASSWORD: 'client',
  PGUSER: 'bgrosse',
  PGDATABASE: 'nodice',
  BOT_TOKEN: '423731161:AAGtwf2CmhOFOnwVocSwe0ylyh63zCyfzbo',
  BOT_GAME: 'QueDiceTest',
  BOT_OFFICIAL_GROUPS: '',
  AVATAR_PATH: '/Users/bgrosse/o/edice/html/pictures',
  PICTURE_URL_PREFIX: '/pictures/',
};

const tableEnv = env => tag => Object.assign({
  TABLE: tag,
}, env);

const tableApp = ({ tag }) => ({
  name: 'nodice-' + tag.toLowerCase(),
  script: 'table.js',
  env: tableEnv(env_local)(tag),
  env_production: tableEnv(env_production)(tag),
  source_map_support: false,
  wait_ready: true,
  restart_delay: 1000,
  vizion: false,
  max_restarts: 5,
});

module.exports = {
  /**
   * Application configuration section
   * http://pm2.keymetrics.io/docs/usage/application-declaration/
   */
  apps : [

    // First application
    {
      name: 'main',
      script: 'main.js',
      env: env_local,
      env_production: env_production,
      source_map_support: false,
      wait_ready: true,
      restart_delay: 1000,
      vizion: false,
      max_restarts: 5,
    },
    {
      name: 'telegram',
      script: 'telegram.js',
      env: env_local,
      env_production: env_production,
      source_map_support: false,
      wait_ready: true,
      restart_delay: 1000,
      vizion: false,
      max_restarts: 5,
    },
  ].concat(tableConfig.tables.map(tableApp)),
};
