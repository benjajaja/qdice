const R = require('ramda');
const probe = require('pmx').probe();

const maps = require('./maps');
const publish = require('./table/publish');
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
      require('./table/enter')(req.user, table, req.body, res, next);
      break;
    case 'Join':
      require('./table/join')(req.user, table, res, next);
      break;
    case 'Leave':
      require('./table/leave')(req.user, table, res, next);
      break;
    case 'Attack':
      require('./table/attack')(req.user, table, req.body, res, next);
      break;
    case 'EndTurn':
      require('./table/endTurn')(req.user, table, res, next);
      break;
    default:
      return next(new Error('Unknown command: ' + command));
  }
};




const tick = require('./table/tick');
module.exports.tick = () => tick(module.exports.getTables());

module.exports.setMqtt = (...args) => {
  publish.setMqtt(...args);
  // crash recovery
  tables.forEach(table => publish.tableStatus(table));
};

