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

let intervalId = null;
module.exports.start = table => {
  if (intervalId !== null) {
    throw new Error('already ticking');
  }
  intervalId = setInterval(tick.bind(null, table), 500);
};
module.exports.stop = table => {
  if (intervalId === null) {
    throw new Error('cannot stop, not ticking');
  }
  clearInterval(intervalId);
  intervalId = null;
};

const tick = table => {
  if (table.status === STATUS_PLAYING) {
    if (table.turnStarted < Date.now() / 1000 - (TURN_SECONDS + 1)) {
      nextTurn(table);
      publish.tableStatus(table);
    } else if (table.players.every(R.prop('out'))) {
      nextTurn(table);
      publish.tableStatus(table);
    }

  } else if (table.status === STATUS_PAUSED) {
    if (table.players.length >= 2
        && table.gameStart !== 0
        && table.gameStart < Date.now() / 1000) {
      startGame(table);
      publish.tableStatus(table);
    }
  }

  const [ stillWatching, stoppedWatching ] = table.watching.reduce(([yes, no], watcher) => {
    if (watcher.lastBeat > Date.now() - 30 * 1000) {
      return [R.append(watcher, yes), no];
    } else {
      return [yes, R.append(watcher, no)];
    }
  }, [[], []]);
  table.watching = stillWatching;
  if (stoppedWatching.length > 0) {
    publish.event({
      type: 'watching',
      table: table.name,
      watching: table.watching.map(R.prop('name')),
    });
  }

  //const newUpdate = require('../global').getTablesStatus(tables);
  //if (!R.equals(newUpdate)(globalTablesUpdate)) {
    //globalTablesUpdate = newUpdate;
    //publish.tables(globalTablesUpdate);
    //probe.metric({
      //name: 'Players',
      //value: R.always(R.sum(R.map(R.prop('playerCount'))(newUpdate))),
    //});
    //updateCounter.inc();
  //}
};

