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
      },
      env_production : {
        NODE_ENV: 'production',
        GOOGLE_OAUTH_SECRET: 'e8Nkmj9X05_hSrrREcRuDCFj',
        PORT: 5001,
        JWT_SECRET: 'dnauh23uasjdnlnalkslk1daWDEDasdd1madremia',
        MQTT_URL: 'mqtt://localhost:1188',
      }
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
