const publish = require('./publish');
const startGame = require('./start');
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
  if (existing) {
    return next(new Error('already joined'));
  } else {
    table.players.push(Player(user));
  }

  table.players = table.players.map((player, index) => Object.assign(player, { color: index + 1}));
  if (table.players.length === table.playerSlots) {
    startGame(table);
  } else {
    if (table.players.length >= 2 &&
      Math.ceil(table.playerSlots / 2) <= table.players.length) {
      table.gameStart = Math.floor(Date.now() / 1000) + GAME_START_COUNTDOWN;
    }
    publish.tableStatus(table);
  }
  res.send(204);
  next();
  require('../telegram').notify(`${user.name} joined https://quedice.host/#${table.name}`);
};

const Player = user => ({
  id: user.id,
  name: user.name,
  picture: user.picture || '',
  color: COLOR_NEUTRAL,
  reserveDice: 0,
  derived: {
    connectedLands: 0,
    totalLands: 0,
    currentDice: 0,
  },
});
  
