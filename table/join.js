const R = require('ramda');
const publish = require('./publish');
const startGame = require('./start');
const tick = require('./tick');
const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} = require('../constants');

const Player = (user, clientId) => ({
  id: user.id,
  clientId,
  name: user.name,
  picture: user.picture || '',
  color: COLOR_NEUTRAL,
  reserveDice: 0,
  out: false,
  outTurns: 0,
  points: user.points,
  level: user.level,
  position: 0,
  score: 0,
});
  
module.exports = (user, table, clientId) => {
  if (table.status === STATUS_PLAYING) {
    return publish.clientError(clientId, new Error('already playing'));
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (existing) {
    return publish.clientError(clientId, new Error('already joined'));
  }

  table.players.push(Player(user, clientId));
  if (table.status === STATUS_FINISHED) {
    table.status = STATUS_PAUSED;
    table.lands = table.lands.map(land => Object.assign({}, land, {
      points: 1,
      color: -1,
    }));
    table.turnCount = 1;
    tick.start(table);
  }

  table.players = table.players.map((player, index) => Object.assign(player, { color: index + 1}));

  if (table.players.length === table.playerSlots) {
    startGame(table);
  } else {
    if (table.players.length >= 2 &&
      table.players.length >= table.startSlots) {
      table.gameStart = Math.floor(Date.now() / 1000) + GAME_START_COUNTDOWN;
      publish.event({
        type: 'countdown',
        table: table.name,
      });
    }
    publish.tableStatus(table);
  }
  publish.event({
    type: 'join',
    table: table.name,
    player: R.last(table.players),
  });
};

