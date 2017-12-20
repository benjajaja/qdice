if (process.env.NODE_ENV !== 'production') {
  console.log('Loading local .env vars')
  require('./envs');
}


const restify = require('restify');
const corsMiddleware = require('restify-cors-middleware');
const jwt = require('restify-jwt-community');


const server = restify.createServer({
  formatters: {
    //'application/json': (request, response, body) => {
      //if (body instanceof Error) {
        //console.error('oh boy it pooped again', body);
        //return JSON.stringify({
          //error: '💣 Error: ' + body.message
        //});
      //}
      //return JSON.stringify(body);
    //},
  },
});
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
  origins: ['http://localhost:5000', 'http://lvh.me:5000', 'https://quedice.host', 'https://elm-dice.herokuapp.com'],
  allowHeaders: ['authorization'],
  exposeHeaders: ['authorization']
});
server.pre(cors.preflight);
server.use(cors.actual);
server.use(jwt({
  secret: process.env.JWT_SECRET,
  credentialsRequired: false,
  getToken: function fromHeaderOrQuerystring (req) {
    if (req.headers.authorization && req.headers.authorization.split(' ')[0] === 'Bearer') {
        return req.headers.authorization.split(' ')[1];
    }
    return null;
  },
}).unless({path: ['/login']}));
server.on('restifyError', function(req, res, err, callback) {
  console.error(err);
  return callback();
});

server.post('/login', require('./user').login);
server.get('/me', require('./user').me);
server.post('/profile', require('./user').profile);

const tables = require('./tables');
server.post('/tables/:tableName/:command', tables.command);

server.get('/global', require('./global')(tables.getTables));

server.listen(process.env.PORT || 5001, function() {
  console.log('%s listening at %s port %s', server.name, server.url);
});

setInterval(function tick() {
  tables.tick();
}, 500);


const mqtt = require('mqtt');
console.log('connecting to mqtt...');
var client = mqtt.connect(process.env.MQTT_URL, {
  username: process.env.MQTT_USERNAME,
  password: process.env.MQTT_PASSWORD,
});
tables.setMqtt(client);
 
client.on('connect', function () {
  console.log('mqtt connected');

  client.subscribe(
    tables.keys.map(table => 'tables/' + table + '/server')
      .concat(tables.keys.map(table => 'tables/' + table + '/broadcast'))
      .concat(['presence']),
    (err, granted) => {
      console.log(err, granted)
      client.publish('presence', 'Hello mqtt', undefined, (err) => console.log(err, 'published presence'));
    });

});

client.on('message', function (topic, message) {
  // message is Buffer 
  //console.log('============== MESSAGE =============');
  //console.log(topic, message.toString())
  // client.end()
});

client.on('error', err => console.error(err));

