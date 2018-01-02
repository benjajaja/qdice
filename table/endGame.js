const publish = require('./publish');
const tick = require('./tick');
const elimination = require('./elimination');
const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  COLOR_NEUTRAL,
  ELIMINATION_REASON_OUT,
  ELIMINATION_REASON_WIN,
} = require('../constants');


module.exports = table => {
  console.log('game finished');
  const winner = table.players.shift();
  elimination(table, winner, ELIMINATION_REASON_WIN);
  table.players = [];
  table.status = STATUS_FINISHED;
  table.turnIndex = -1;
  table.gameStart = 0;
  tick.stop(table);
  publish.event({
    type: 'end',
    table: table.name,
  });
};

