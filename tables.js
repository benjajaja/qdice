
const keys = ['Melchor', 'Miño'];
module.exports.keys = keys;

const T_CLIENTS = 'clients';

const Table = name => ({
  name,
  players: [],
  spectators: [],
  playerSlotCount: 2,
  status: 'PAUSED',
});

const Player = user => ({
  id: user.id,
  name: user.name,
  picture: user.picture,
  color: -1,
});
  
const tables = keys.map(key => Table(key));

const findTable = tables => name => tables.filter(table => table.name === name).pop();

module.exports.command = function(req, res, next) {
  const table = findTable(tables)(req.params.tableName);
  if (!table) throw new Error('table not found: ' + req.params.tableName);
  const command = req.params.command;
  switch (command) {
    case 'Enter':
      enter(req.user, table, req);
      break;
    case 'Join':
      join(req.user, table, req);
      break;
    case 'Leave':
      leave(req.user, table, req);
      break;
    default:
      throw new Error('Unknown command: ' + command);
  }
  res.send(204);
  next();
};

const enter = (user, table) => {
  const player = Player(user);
  const existing = table.spectators.filter(p => p.id === player.id).pop();
  if (existing) {
    table.spectators[table.spectators.indexOf(existing)] =
      Object.assign({}, existing, player);
  } else {
    table.spectators.push(player);
  }
  publishTableStatus(table);
};

const join = (user, table) => {
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (existing) {
    throw new Error('already joined');
  } else {
    table.players.push(Player(user));
  }
  publishTableStatus(table);
};


const leave = (user, table) => {
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    throw new Error('not joined');
  } else {
    table.players = table.players.filter(p => p !== existing);
  }
  publishTableStatus(table);
};


let client;
module.exports.setMqtt = client_ => {
  client = client_;
  client.on('message', (topic, message) => {
    if (topic.indexOf('tables/') !== 0) return;
    const [ _, tableName, channel ] = topic.split('/');
    const table = findTable(tables)(tableName);
    if (!table) throw new Error('table not found: ' + tableName);
    const { type, payload } = JSON.parse(message);
    console.log('table message', tableName, channel);
    //publishTableStatus(table);
  });
};

const publishTableStatus = table => {
  client.publish('tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'update',
      payload: table,
    }),
    undefined,
    (err) => console.log(err, 'tables/' + table.name + '/clients',
      JSON.stringify({
      type: 'update',
      payload: table,
    }))
  );
};

