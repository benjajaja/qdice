const R = require('ramda');
const maps = require('../maps');
const { rand } = require('../rand');

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
