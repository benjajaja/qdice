const R = require('ramda');
const maps = require('../maps');
const { rand } = require('../rand');

const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
} = require('../constants');

module.exports = table => {
  if (table.turnIndex !== -1) {
    giveDice(table)(table.players[table.turnIndex]);
  }

  const nextIndex = (i => i + 1 < table.players.length ? i + 1 : 0)(table.turnIndex);
  table.turnIndex = nextIndex;
  table.turnStarted = Math.floor(Date.now() / 1000);
  if (!table.players.every(R.prop('out'))) {
    const newPlayer = table.players[table.turnIndex];
    if (newPlayer.out) {
      newPlayer.outTurns += 1;
      if (newPlayer.outTurns > 5) {
        table = removePlayer(table)(newPlayer);
        if (table.players.length === 1) {
          endGame(table);
        }
      }
      return module.exports(table);
    }
  }
  return table;
};

const giveDice = table => player => {
  const playerLands = table.lands.filter(land => land.color === player.color);
  const newDies =
    maps.countConnectedLands(table)(player.color)
    + player.reserveDice;
  player.reserveDice = 0;

  R.range(0, newDies).forEach(i => {
    const targets = playerLands.filter(land => land.points < 8);
    if (targets.length === 0) {
      player.reserveDice += 1;
    } else {
      const target = targets[rand(0, targets.length - 1)];
      target.points += 1;
    }
  });
};

const removePlayer = table => player => {
  table.players = table.players.filter(R.complement(R.equals(player)));
  table.lands = table.lands.map(R.when(R.propEq('color', player.color), land => Object.assign(land, { color: COLOR_NEUTRAL })));
  return table;
};

const endGame = table => {
  table.players = [];
  table.status = STATUS_FINISHED;
  table.turnIndex = -1;
  table.gameStart = 0;
};

