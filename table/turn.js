const R = require('ramda');
const maps = require('../maps');
const { rand } = require('../rand');

module.exports = table => {
  if (table.turnIndex !== -1) {
    const currentTurnPlayer = table.players[table.turnIndex];
    const playerLands = table.lands.filter(land => land.color === currentTurnPlayer.color);
    const newDies =
      maps.countConnectedLands(table)(currentTurnPlayer.color)
      + currentTurnPlayer.reserveDice;
    currentTurnPlayer.reserveDice = 0;

    R.range(0, newDies).forEach(i => {
      const targets = playerLands.filter(land => land.points < 8);
      if (targets.length === 0) {
        currentTurnPlayer.reserveDice += 1;
      } else {
        const target = targets[rand(0, targets.length - 1)];
        target.points += 1;
      }
    });
  }

  const nextIndex = (i => i + 1 < table.players.length ? i + 1 : 0)(table.turnIndex);
  table.turnIndex = nextIndex;
  table.turnStarted = Math.floor(Date.now() / 1000);
  return table;
};


