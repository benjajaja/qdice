var R = require('ramda');
var { serializeTable } = require('./tables');
const {
  TURN_SECONDS,
  GAME_START_COUNTDOWN,
  MAX_NAME_LENGTH,
} = require('./constants');

module.exports = function(getTables) {
  return function(req, res, next) {
    res.send(200, {
      settings: {
        turnSeconds: TURN_SECONDS,
        gameCountdownSeconds: GAME_START_COUNTDOWN,
        maxNameLength: MAX_NAME_LENGTH,
      },
      tables: getTablesStatus(getTables()),
    });
    next();
  };
};

const getTablesStatus = module.exports.getTablesStatus = tables =>
  tables.map(table =>
    Object.assign(R.pick([
      'name',
      'stackSize',
      'status',
      'playerSlots',
    ])(table), {
      landCount: table.lands.length,
      playerCount: table.players.length,
    })
  );
