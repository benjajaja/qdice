import * as dotenv from 'dotenv';

import logger from './logger';
import * as db from './db';
import * as table from './table';

import * as R from 'ramda';

import * as restify from 'restify';
import * as corsMiddleware from 'restify-cors-middleware';
import * as jwt from 'restify-jwt-community';
import * as mqtt from 'mqtt';

import * as globalServer from './global';
import { leaderboard } from './leaderboard';
import * as publish from './table/publish';
import * as user from './user';

dotenv.config();

const server = restify.createServer();
server.pre(restify.pre.userAgentConnection());
server.use(restify.plugins.acceptParser(server.acceptable));
server.use(restify.plugins.authorizationParser());
server.use(restify.plugins.dateParser());
server.use(restify.plugins.queryParser());
server.use(restify.plugins.jsonp());
server.use(restify.plugins.gzipResponse());
server.use(restify.plugins.bodyParser());
server.use(restify.plugins.throttle({
  burst: 100,
  rate: 50,
  ip: true,
  overrides: {
    '192.168.1.1': {
      rate: 0,        // unlimited
      burst: 0
    }
  }
}));
server.use(restify.plugins.conditionalRequest());
const cors = corsMiddleware({
  preflightMaxAge: 5, //Optional
  origins: ['http://localhost:5000', 'http://lvh.me:5000', 'https://quedice.host', 'https://quevic.io', 'https://qdice.wtf', 'https://www.qdice.wtf', 'https://elm-dice.herokuapp.com', 'https://*.hwcdn.net'],
  allowHeaders: ['authorization'],
  exposeHeaders: ['authorization']
});
server.pre(cors.preflight);
server.use(cors.actual);
server.use(jwt({
  secret: process.env.JWT_SECRET,
  credentialsRequired: true,
  getToken: function fromHeaderOrQuerystring (req: any) {
    if (req.headers.authorization && req.headers.authorization.split(' ')[0] === 'Bearer') {
        return req.headers.authorization.split(' ')[1] || null;
    }
    return null;
  },
})
.unless({
  custom: (req: any) => {
    const ok = R.anyPass([
      (req: any) => req.path() === '/login',
      (req: any) => req.path() === '/register',
      (req: any) => req.path() === '/global',
      (req: any) => req.path() === '/findtable',
      (req: any) => req.path() === '/leaderboard',
    ])(req);
    return ok;
  }
}));


server.post('/login', user.login);
server.get('/me', user.me);
server.put('/profile', user.profile);
server.post('/register', user.register);


server.get('/global', globalServer.global);
server.get('/findtable', globalServer.findtable);
server.get('/leaderboard', leaderboard);

db.connect().then(() => {
  logger.info('connected to postgres.');

  server.listen(process.env.PORT || 5001, function() {
    logger.info('%s listening at %s port %s', server.name, server.url);
  });

  logger.info('connecting to mqtt: ' + process.env.MQTT_URL);
  var client = mqtt.connect(process.env.MQTT_URL, {
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
  });
  publish.setMqtt(client);

  client.subscribe('events');
  client.on('error', (err: Error) => logger.error(err));
  client.on('connect', () => {
    logger.info('connected to mqtt.');
    if (process.send) {
      process.send('ready');
    }
    publish.setMqtt(client);

  });
  table.start('España', client);
  table.start('Arabia', client);

  client.on('message', globalServer.onMessage);

  //process.on('SIGINT', () => {
    //(client.end as any)(() => {
      //logger.info('main stopped gracefully');
      //process.exit(0);
    //});
  //});

});

process.on('unhandledRejection', (reason, p) => {
  logger.error('Unhandled Rejection at: Promise', p, 'reason:', reason);
  // application specific logging, throwing an error, or other logic here
  throw reason
});

