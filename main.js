if (process.env.NODE_ENV !== 'production') {
  console.log('Loading local .env vars')
  require('./envs');
}


const restify = require('restify');
const corsMiddleware = require('restify-cors-middleware');
const jwt = require('restify-jwt');


var server = restify.createServer();
server.pre(restify.pre.userAgentConnection());
server.use(restify.acceptParser(server.acceptable));
server.use(restify.authorizationParser());
server.use(restify.dateParser());
server.use(restify.queryParser());
server.use(restify.jsonp());
server.use(restify.gzipResponse());
server.use(restify.bodyParser());
server.use(restify.throttle({
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
server.use(restify.conditionalRequest());
const cors = corsMiddleware({
  preflightMaxAge: 5, //Optional
  origins: ['http:localhost:5000', 'http://lvh.me:5000', 'http://elm-dice.herokuapp.com', 'https://elm-dice.herokuapp.com'],
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

server.post('/login', require('./user').login);
server.get('/me', require('./user').me);
server.post('/profile', require('./user').profile);

const tables = require('./tables');
server.post('/tables/:tableName/:command', tables.command);

server.listen(process.env.PORT || 5001, function() {
  console.log('%s listening at %s port %s', server.name, server.url);
});




const mqtt = require('mqtt');
var client = mqtt.connect('tcp://m21.cloudmqtt.com:11201', {
  username: 'web',
  password: 'web',
})
 
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

  tables.setMqtt(client);
});

client.on('message', function (topic, message) {
  // message is Buffer 
  //console.log('============== MESSAGE =============');
  //console.log(topic, message.toString())
  // client.end()
});

client.on('error', err => console.error(err));

