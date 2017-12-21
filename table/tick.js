const R = require('ramda');
const probe = require('pmx').probe();

const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
} = require('../constants');
const nextTurn = require('./turn');
const publish = require('./publish');
const startGame = require('./start');

let globalTablesUpdate = null;

const updateCounter = probe.counter({
  name : 'Global mqtt updates'
});


module.exports = tables => {
  tables.filter(table => table.status === STATUS_PLAYING)
    .forEach(table => {
    if (table.turnStarted < Date.now() / 1000 - (TURN_SECONDS + 1)) {
      nextTurn(table);
      publish.tableStatus(table);
    }
  });

  tables.filter(table => table.status !== STATUS_PLAYING)
    .forEach(table => {
    if (table.players.length >= 2
        && table.gameStart !== 0
        && table.gameStart + 1 < Date.now() / 1000) {
      startGame(table);
      publish.tableStatus(table);
    }
  });

  const newUpdate = require('../global').getTablesStatus(tables);
  if (!R.equals(newUpdate)(globalTablesUpdate)) {
    globalTablesUpdate = newUpdate;
    publish.tables(globalTablesUpdate);
    console.log('global table list update push');
    probe.metric({
      name: 'Players',
      value: R.always(R.sum(R.map(R.prop('playerCount'))(newUpdate))),
    });
    updateCounter.inc();
  }
};

