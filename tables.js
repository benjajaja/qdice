const fs = require('fs');
const R = require('ramda');

const keys = ['Melchor', 'Miño'];
module.exports.keys = keys;

const T_CLIENTS = 'clients';

const STATUS_PAUSED = 'PAUSED';
const STATUS_PLAYING = 'PLAYING';
const STATUS_FINISHED = 'FINISHED';

const TURN_SECONDS = 10;

const Table = name => ({
  name,
  players: [],
  spectators: [],
  playerSlots: 2,
  status: STATUS_PAUSED,
  turnIndex: -1,
  turnStarted: 0,
  lands: [],
});

const loadLands = table => {
  const rawMap = fs.readFileSync('./maps/' + table.name + '.emoji')
    .toString().split('\n').filter(line => line !== '');
  const regex = new RegExp('〿|\\u3000|[\\uD800-\\uDBFF][\\uDC00-\\uDFFF]', 'gi');

  const rows = rawMap.map(line => {
    const results = [];
    let result;
    let index = 0;
    while (result = regex.exec(line)){
      results.push([index, result[0]]);
      index++;
    }
    return results;
  });
  //const maxWidth = rows.map(row => row.length).reduce((max, width) => Math.max(max, width));
  const lands = R.uniq(rows.map(row => row.map(cell => cell[1])).reduce(R.concat, []))
    .filter(R.complement(R.equals('〿')))
    .filter(R.complement(R.equals('\u3000')))
    .map(emoji => ({
      emoji: emoji,
      color: -1,
      points: Math.floor(Math.random() * 3 + 1),
    }));
  table.lands = lands;
  return table;
};

const Player = user => ({
  id: user.id,
  name: user.name,
  picture: user.picture,
  color: -1,
});
  
const tables = keys.map(key =>loadLands(Table(key)));
const tableTimeouts = keys.reduce((obj, key) => Object.assign(obj, { [key]: null }));

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

  if (table.players.length === table.playerSlots) {
    startGame(table);
  } else {
    publishTableStatus(table);
  }
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
    //console.log('table message', tableName, channel);
    //publishTableStatus(table);
  });
  tables.forEach(publishTableStatus);
};

const publishTableStatus = table => {
  //console.log('publish', table);
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

const startGame = table => {
  table.status = STATUS_PLAYING;
  table.players = table.players
    .map((player, index) => Object.assign({}, player, { color: index + 1 }));

  const startLands = (() => {
    function shuffle(a) {
      for (let i = a.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [a[i], a[j]] = [a[j], a[i]];
      }
      return a;
    }
    return shuffle(table.lands.slice()).slice(0, table.players.length);
  })();
  table.players.forEach((player, index) => {
    const land = startLands[index];
    land.color = player.color;
    land.points = 4;
    console.log(player.name, land);
  });
  
  table = nextTurn(table);
  return table;
};

const nextTurn = table => {
  const nextIndex = (i => i + 1 < table.playerSlots ? i + 1 : 0)(table.turnIndex);
  table.turnIndex = nextIndex;
  table.turnStarted = Math.floor(Date.now() / 1000);
  publishTableStatus(table);
  return table;
};

module.exports.tick = () => {
  tables.filter(table => table.status === STATUS_PLAYING)
    .forEach(table => {
    if (table.turnStarted < Date.now() / 1000 - TURN_SECONDS) {
      //console.log('tick turn', table.name);
      nextTurn(table);
    }
  });
};

