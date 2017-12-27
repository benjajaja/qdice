const R = require('ramda');
const maps = require('../maps');
const publish = require('./publish');
const endGame = require('./endGame');
const { rand } = require('../rand');

const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  ELIMINATION_REASON_OUT,
  ELIMINATION_REASON_WIN,
} = require('../constants');

module.exports = table => {
  const currentPlayer = table.players[table.turnIndex];
  if (!table.turnActivity && !currentPlayer.out) {
    currentPlayer.out = true;
  }
  giveDice(table)(currentPlayer);

  const nextIndex = (i => i + 1 < table.players.length ? i + 1 : 0)(table.turnIndex);
  table.turnIndex = nextIndex;
  table.turnStarted = Math.floor(Date.now() / 1000);
  table.turnActivity = false;

  const newPlayer = table.players[table.turnIndex];
  if (newPlayer.out) {
    newPlayer.outTurns += 1;
    if (newPlayer.outTurns > 5) {
      publish.elimination(table, newPlayer, table.players.length, {
        type: ELIMINATION_REASON_OUT,
        source: newPlayer.outTurns,
      });

      table = removePlayer(table)(newPlayer);


      if (table.players.length === 1) {
        endGame(table);
      }
    }
    if (!table.players.every(R.prop('out'))) {
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

