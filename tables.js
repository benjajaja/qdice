const R = require('ramda');
const probe = require('pmx').probe();

const maps = require('./maps');
const publish = require('./table/publish');
const nextTurn = require('./table/turn');
const startGame = require('./table/start');
const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} = require('./constants');
const { findTable, hasTurn } = require('./helpers');


const keys = ['Melchor', 'Miño', 'Avocado', 'Sabicas' ];


const Table = name => ({
  name,
  players: [],
  playerSlots: 2,
  status: STATUS_PAUSED,
  gameStart: 0,
  turnIndex: -1,
  turnStarted: 0,
  lands: [],
  stackSize: 8,
});


const loadLands = table => {
  const [ lands, adjacency ] = maps.loadMap(table.name);
  return Object.assign({}, table, {
    lands: lands.map(land => Object.assign({}, land, {
      color: COLOR_NEUTRAL,
      points: 1,
    })),
    adjacency
  });
};

const Player = user => ({
  id: user.id,
  name: user.name,
  picture: user.picture || '',
  color: COLOR_NEUTRAL,
  reserveDice: 0,
  derived: {
    connectedLands: 0,
    totalLands: 0,
    currentDice: 0,
  },
});
  
console.log('loading tables and calculating adjacency matrices...');
const tables = keys.map(key =>loadLands(Table(key)));
tables[0].playerSlots = 4;
tables[2].playerSlots = 5;
if (tables[3]) tables[3].playerSlots = 7;
//tables.forEach(table =>
  //table.players = R.range(0,7).map(i =>
    //Object.assign(Player({
      //id: `fake_${i}`,
      //name: `Pikachu${i} Random name`,
      //picture: 'http://i.imgur.com/WgP9bNm.jpg',
    //}), {
      //color: i + 1
    //})
  //)
//);
module.exports.getTables = function() {
  return tables;
};



module.exports.command = function(req, res, next) {
  const table = findTable(tables)(req.context.tableName);
  if (!table) {
		return next(new Error('table not found: ' + req.context.tableName));
	}
  const command = req.context.command;
  switch (command) {
    case 'Enter':
      enter(req.user, table, req.body, res, next);
      break;
    case 'Join':
      join(req.user, table, res, next);
      break;
    case 'Leave':
      leave(req.user, table, res, next);
      break;
    case 'Attack':
      require('./table/attack')(req.user, table, req.body, res, next);
      break;
    case 'EndTurn':
      endTurn(req.user, table, res, next);
      break;
    default:
      return next(new Error('Unknown command: ' + command));
  }
};

const enterCounter = probe.counter({
  name : 'Table enter',
});
const enter = (user, table, clientId, res, next) => {
  publish.tableStatus(table, clientId);
  enterCounter.inc();
  res.send(204);
  next();
};

const join = (user, table, res, next) => {
  console.log('join', user.name);
  if (table.status === STATUS_PLAYING) {
    res.send(406);
    return next();
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (existing) {
    return next(new Error('already joined'));
  } else {
    table.players.push(Player(user));
  }

  table.players = table.players.map((player, index) => Object.assign(player, { color: index + 1}));
  if (table.players.length === table.playerSlots) {
    startGame(table);
  } else {
    if (table.players.length >= 2 &&
      Math.ceil(table.playerSlots / 2) <= table.players.length) {
      table.gameStart = Math.floor(Date.now() / 1000) + GAME_START_COUNTDOWN;
    }
    publish.tableStatus(table);
  }
  res.send(204);
  next();
  require('./telegram').notify(`${user.name} joined https://quedice.host/#${table.name}`);
};


const leave = (user, table, res, next) => {
  if (table.status === STATUS_PLAYING) {
    res.send(406);
    return next();
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    return next(new Error('not joined'));
  } else {
    table.players = table.players.filter(p => p !== existing);
  }
  if (table.players.length >= 2 &&
    Math.ceil(table.playerSlots / 2) <= table.players.length) {
    table.gameStart = Math.floor(Date.now() / 1000) + 30;
  } else {
    table.gameStart = 0;
  }
  table.players = table.players.map((player, index) => Object.assign(player, { color: index + 1 }));
  publish.tableStatus(table);
  res.send(204);
  next();
};

const endTurn = (user, table, res, next) => {
  if (table.status !== STATUS_PLAYING) {
    return next(new Error('game not running'));
  }
  if (!hasTurn(table)(user)) {
    return next(new Error('out of turn'));
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    return next(new Error('not playing'));
  }

  nextTurn(table);
  publish.tableStatus(table);
  res.send(204);
  next();
};



const tick = require('./table/tick');
module.exports.tick = () => tick(module.exports.getTables());

module.exports.setMqtt = (...args) => {
  publish.setMqtt(...args);
  // crash recovery
  tables.forEach(table => publish.tableStatus(table));
};

