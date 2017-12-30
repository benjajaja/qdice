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

module.exports = (user, table, clientId) => {
  if (table.status !== STATUS_PLAYING) {
    return publish.clientError(clientId, new Error('game not running'));
  }
  if (!hasTurn(table)(user)) {
    return publish.clientError(clientId, new Error('out of turn'));
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    return publish.clientError(clientId, new Error('not playing'));
  }

  table.turnActivity = true;
  nextTurn(table);
  publish.tableStatus(table);
};

