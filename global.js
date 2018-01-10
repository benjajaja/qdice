var R = require('ramda');

const {
  TURN_SECONDS,
  GAME_START_COUNTDOWN,
  MAX_NAME_LENGTH,
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
} = require('./constants');
const publish = require('./table/publish');
const { findTable } = require('./helpers');
const maps = require('./maps');

const tablesConfig = require('./tables.config');

const tables = tablesConfig.tables.map(config => {
  const [ lands, adjacency ] = maps.loadMap(config.tag);
  return {
    tag: config.tag,
    name: config.tag,
    playerSlots: config.playerSlots,
    stackSize: config.stackSize,
    points: config.points,
    status: STATUS_PAUSED,
    landCount: lands.length,
    players: [],
    watching: [],
  };
});

module.exports.global = function(req, res, next) {
  res.send(200, {
    settings: {
      turnSeconds: TURN_SECONDS,
      gameCountdownSeconds: GAME_START_COUNTDOWN,
      maxNameLength: MAX_NAME_LENGTH,
    },
    tables: getTablesStatus(tables),
  });
  next();
};

module.exports.findtable = (req, res, next) => {
  res.send(200, R.pipe(
    R.map(table => [table.name, table.players.length]),
    R.reduce(R.maxBy(R.nth(1)), ['', -1]),
    R.nth(0),
  )(tables));
};

const getTablesStatus = module.exports.getTablesStatus = (tables) =>
  tables.map(table =>
    Object.assign(R.pick([
      'name',
      'tag',
      'stackSize',
      'status',
      'playerSlots',
      'landCount',
      'points',
    ])(table), {
      playerCount: table.players.length,
      watchCount: table.watching.length,
    })
  );

module.exports.onMessage = (topic, message) => {
  try {
    if (topic === 'events') {
      const event = JSON.parse(message);
      switch (event.type) {

        case 'join': {
          const table = findTable(tables)(event.table);
          if (!table) {
            return;
          }
          table.players.push(event.player);
          publish.tables(getTablesStatus(tables));

          return;
        }

        case 'leave': {
          const table = findTable(tables)(event.table);
          if (!table) {
            return;
          }
          table.players = table.players.filter(p => p.id !== event.player.id);
          publish.tables(getTablesStatus(tables));
          return;
        }

        case 'elimination': {
          const { player, position, score } = event;
          const table = findTable(tables)(event.table);
          table.players = table.players.filter(p => p.id === event.player.id);
          publish.tables(getTablesStatus(tables));
          return;
        }

        case 'watching': {
          const table = findTable(tables)(event.table);
          if (!table) {
            return;
          }

          table.watching = event.watching;
          publish.tables(getTablesStatus(tables));

          return;
        }

      }
    }
  } catch (e) {
    console.error('table list event error', e);
  }
};

