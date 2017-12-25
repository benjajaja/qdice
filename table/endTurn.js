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
    return next(new Error('game not running'));
  }
  if (!hasTurn(table)(user)) {
    return next(new Error('out of turn'));
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    return next(new Error('not playing'));
  }

  nextTurn(table);
  publish.tableStatus(table);
  res.send(204);
  next();
};

