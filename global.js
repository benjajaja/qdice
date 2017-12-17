var R = require('ramda');
var { serializeTable } = require('./tables');

module.exports = function(getTables) {
  return function(req, res, next) {
    res.send(200, {
      settings: null,
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
