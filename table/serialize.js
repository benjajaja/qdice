const R = require('ramda');

const maps = require('../maps');

module.exports.serializeTable = table => {
  const derived = computePlayerDerived(table);
  const players = table.players.map(player => Object.assign({}, player, { derived: derived(player) }));
  const lands = table.lands.map(({ emoji, color, points }) => ({ emoji, color, points, }));

  const result = Object.assign({}, R.pick([
    'name', 'playerSlots', 'status', 'turnIndex', 'turnStarted'
  ])(table), {
    players,
    lands
  });
  return result;
};

const computePlayerDerived = table => player => {
  const lands = table.lands.filter(R.propEq('color', player.color));
  const connectedLands = maps.countConnectedLands(table)(player.color);
  return {
    connectedLands,
    totalLands: lands.length,
    currentDice: R.sum(lands.map(R.prop('points'))),
  };
};

