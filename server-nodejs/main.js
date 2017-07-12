var restify = require('restify');
var mqtt = require('mqtt');

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

server.get('/hello/:name', respond);
server.head('/hello/:name', respond);

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

server.listen(5001, function() {
  console.log('%s listening at %s', server.name, server.url);
});

var client  = mqtt.connect('tcp://localhost:1883')
 
client.on('connect', function () {
  Object.keys(tables).forEach(key => {
    client.subscribe('tables/' + key + '/server');
    client.subscribe('tables/' + key + '/broadcast');
  });
  client.subscribe('presence')
  client.publish('presence', 'Hello mqtt')
})

client.on('message', function (topic, message) {
  // message is Buffer 
  console.log(message.toString())
  // client.end()
})
