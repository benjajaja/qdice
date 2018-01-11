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
  const winner = table.players[0];
  console.log('game finished', winner);
  elimination(table, winner, ELIMINATION_REASON_WIN, {
    turns: table.turnCount,
  });
  table.players = [];
  table.status = STATUS_FINISHED;
  table.turnIndex = -1;
  table.gameStart = 0;
  table.turnCount = 1;
  table.roundCount = 1;
  //tick.stop(table);
  publish.event({
    type: 'end',
    table: table.name,
  });
};

