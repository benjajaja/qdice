const GOOGLE_OAUTH_SECRET = process.env.GOOGLE_OAUTH_SECRET;
if (!GOOGLE_OAUTH_SECRET) throw new Error('GOOGLE_OAUTH_SECRET env var not found');

var restify = require('restify');
var mqtt = require('mqtt');
var request = require('request');

function respond(req, res, next) {
  res.send('hello ' + req.params.name);
  next();
}

var server = restify.createServer();
server.pre(restify.pre.userAgentConnection());
// server.use(restify.acceptParser(server.acceptable));
server.use(restify.authorizationParser());
server.use(restify.dateParser());
server.use(restify.queryParser());
server.use(restify.jsonp());
server.use(restify.gzipResponse());
server.use(restify.bodyParser());
// server.use(restify.requestExpiry());
server.use(restify.CORS());
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

const Table = name => ({
  name,
  players: [],
  spectators: [],
  playerSlotCount: 2,
  status: 'PAUSED',
})

var tables = ['Melchor', 'Miño'].reduce((acc, key) => {
  acc[key] = Table(key);
  return acc;
}, {});

server.post('/login', function(req, res, next) {
  request({
    url: 'https://www.googleapis.com/oauth2/v4/token',
    method: 'POST',
    //headers: {
      //authorization: req.body,
    //},
    form: {
      code: req.body,
      client_id: '1000163928607-54qf4s6gf7ukjoevlkfpdetepm59176n.apps.googleusercontent.com',
      client_secret: GOOGLE_OAUTH_SECRET,
      scope: ['email', 'profile'],
      grant_type: 'authorization_code',
      redirect_uri: req.headers.referer,
    }
  }, function(err, response, body) {
    var json = JSON.parse(body);
    request({
      url: 'https://www.googleapis.com/userinfo/v2/me',
      method: 'GET',
      headers: {
        authorization: json.token_type + ' ' + json.access_token,
      },
    }, function(err, response, body) {
      var profile = JSON.parse(body);
      console.log(profile);
      res.send(200, {
        name: profile.name,
        email: profile.email,
        picture: profile.picture,
      });
      next();
    });
  });
});

server.post('/tables/:name', function(req, res, next) {
  var player = req.body;
  var table = tables[req.params.name];
  var existing = table.players.filter(p => p.name === player.name).pop();
  if (existing) {
    table.players[table.players.indexOf(existing)] =
      Object.assign({}, player, existing);
  } else {
    table.players.push(Object.assign({color: -1}, player));
  }
  res.send({
    players: table.players
  });
  next();
});

server.listen(process.env.PORT || 5001, function() {
  console.log('%s listening at %s port %s', server.name, server.url);
});

var client = mqtt.connect('tcp://m21.cloudmqtt.com:11201', {
  username: 'web',
  password: 'web',
})
 
client.on('connect', function () {
  console.log('mqtt connected');

  client.subscribe(
    Object.keys(tables).map(table => 'tables/' + table + '/server')
      .concat(Object.keys(tables).map(table => 'tables/' + table + '/broadcast'))
      .concat(['presence']),
    (err, granted) => {
      console.log(err, granted)
      client.publish('presence', 'Hello mqtt', undefined, (err) => console.log(err, 'published presence'));
    });
});

client.on('message', function (topic, message) {
  // message is Buffer 
  console.log(message.toString())
  // client.end()
});

client.on('error', err => console.error(err));

