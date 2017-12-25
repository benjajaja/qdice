const R = require('ramda');
const publish = require('./publish');
const nextTurn = require('./turn');
const { hasTurn } = require('../helpers');
const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} = require('../constants');

module.exports = (user, table, res, next) => {
  if (table.status !== STATUS_PLAYING) {
    res.send(406);
    return next();
  }
  const player = table.players.filter(p => p.id === user.id).pop();
  if (!player) {
    return next(new Error('not playing'));
  } else {
    const allOut = table.players.every(R.prop('out'));
    player.out = false;
    player.outTurns = 0;
    if (allOut) {
      nextTurn(table);
    }
  }

  publish.tableStatus(table);
  res.send(204);
  next();
};

