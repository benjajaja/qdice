const publish = require('./publish');
const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} = require('../constants');

module.exports = (user, table, res, next) => {
  if (table.status === STATUS_PLAYING) {
    res.send(406);
    return next();
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    return next(new Error('not joined'));
  } else {
    table.players = table.players.filter(p => p !== existing);
  }
  if (table.players.length >= 2 &&
    Math.ceil(table.playerSlots / 2) <= table.players.length) {
    table.gameStart = Math.floor(Date.now() / 1000) + GAME_START_COUNTDOWN;
  } else {
    table.gameStart = 0;
  }
  table.players = table.players.map((player, index) => Object.assign(player, { color: index + 1 }));
  publish.tableStatus(table);
  res.send(204);
  next();
};

