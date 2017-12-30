const publish = require('./publish');
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
  publish.elimination(table, winner, 1, {
    type: ELIMINATION_REASON_WIN,
  });
  table.players = [];
  table.status = STATUS_FINISHED;
  table.turnIndex = -1;
  table.gameStart = 0;
  publish.event({
    type: 'end',
    table: table.name,
  });
};

