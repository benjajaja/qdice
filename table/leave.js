const publish = require('./publish');
const tick = require('./tick');
const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} = require('../constants');

module.exports = async (user, table, clientId) => {
  if (table.status === STATUS_PLAYING) {
    return publish.clientError(clientId, new Error('already started'));
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    return publish.clientError(clientId, new Error('not joined'));
  }

  table.players = table.players.filter(p => p !== existing);

  if (table.players.length >= 2 &&
    Math.ceil(table.playerSlots / 2) <= table.players.length) {
    table.gameStart = Math.floor(Date.now() / 1000) + GAME_START_COUNTDOWN;
  } else {
    table.gameStart = 0;
  }

  if (table.players.length === 0 && table.status === STATUS_PAUSED) {
    table.status = STATUS_FINISHED;
    tick.stop(table);
  }

  table.players = table.players.map((player, index) => Object.assign(player, { color: index + 1 }));
  publish.tableStatus(table);

  publish.event({
    type: 'leave',
    table: table.name,
    player: existing,
  });
};

