module.exports = {
  /**
   * Application configuration section
   * http://pm2.keymetrics.io/docs/usage/application-declaration/
   */
  apps : [

    // First application
    {
      name      : 'nodice',
      script    : 'main.js',
      env: {
        GOOGLE_OAUTH_SECRET: 'e8Nkmj9X05_hSrrREcRuDCFj',
        PORT: 5001,
        JWT_SECRET: 'dnauh23uasjdnlnalkslk1daWDEDasdd1madremia',
        MQTT_URL: 'mqtt://localhost:11883',
        MQTT_USERNAME: 'client',
        MQTT_PASSWORD: 'client',
        BOT_TOKEN: '423731161:AAGtwf2CmhOFOnwVocSwe0ylyh63zCyfzbo',
        BOT_GAME: 'QueDiceTest',
      },
      env_production : {
        NODE_ENV: 'production',
        GOOGLE_OAUTH_SECRET: 'e8Nkmj9X05_hSrrREcRuDCFj',
        PORT: 5001,
        JWT_SECRET: 'dnauh23uasjdnlnalkslk1daWDEDasdd1madremia',
        MQTT_URL: 'mqtt://localhost:11883',
        MQTT_USERNAME: 'nodice',
        MQTT_PASSWORD: 'PeyY9TYap2vaZxQ8tTMXcD57',
        BOT_TOKEN: '478186891:AAF8m2BYVGF92p0L1oeCUOquvgF6ajLEvxc',
        BOT_GAME: 'QueDice',
      }
    },
    {
      name: 'telegram',
      script: 'telegram.js',
      env: {
        JWT_SECRET: 'dnauh23uasjdnlnalkslk1daWDEDasdd1madremia',
        MQTT_URL: 'mqtt://localhost:11883',
        MQTT_USERNAME: 'client',
        MQTT_PASSWORD: 'client',
        BOT_TOKEN: '423731161:AAGtwf2CmhOFOnwVocSwe0ylyh63zCyfzbo',
        BOT_GAME: 'QueDiceTest',
      },
      env_production: {
        NODE_ENV: 'production',
        JWT_SECRET: 'dnauh23uasjdnlnalkslk1daWDEDasdd1madremia',
        MQTT_URL: 'mqtt://localhost:11883',
        MQTT_USERNAME: 'nodice',
        MQTT_PASSWORD: 'PeyY9TYap2vaZxQ8tTMXcD57',
        BOT_TOKEN: '478186891:AAF8m2BYVGF92p0L1oeCUOquvgF6ajLEvxc',
        BOT_GAME: 'QueDice',
      },
    },

    // Second application
    //{
      //name      : 'WEB',
      //script    : 'web.js'
    //}
  ],

  /**
   * Deployment section
   * http://pm2.keymetrics.io/docs/usage/deployment/
   */
  deploy : {
    production : {
      user : 'node',
      host : '212.83.163.1',
      ref  : 'origin/master',
      repo : 'git@github.com:repo.git',
      path : '/var/www/production',
      'post-deploy' : 'npm install && pm2 reload ecosystem.config.js --env production'
    },
    dev : {
      user : 'node',
      host : '212.83.163.1',
      ref  : 'origin/master',
      repo : 'git@github.com:repo.git',
      path : '/var/www/development',
      'post-deploy' : 'npm install && pm2 reload ecosystem.config.js --env dev',
      env  : {
        NODE_ENV: 'dev'
      }
    }
  }
};
