const R = require('ramda');

const maps = require('../maps');

const scores = {
  1: 90,
  2: 60,
  3: 30,
  4: 10,
  5: 0,
  6: 0,
  7: 0,
  8: 0,
  9: 0,
  10: 0,
};

module.exports.serializeTable = table => {
  const players = table.players.map(serializePlayer(table));
  const sortedPlayers = R.sortBy(R.path(['derived', 'totalLands']))(players).reverse();
  const players_ = players.map(player => {
    const index = sortedPlayers.indexOf(player);
    player.derived.position = index + 1;
    return player;
  }).map(player => {
    const index = sortedPlayers.indexOf(player);
    const previousPlayer = sortedPlayers[index - 1];
    if (previousPlayer && previousPlayer.derived.totalLands ===
      player.derived.totalLands) {
      player.derived.position = previousPlayer.derived.position;
    }
    player.derived.score = scores[player.derived.position] || 0;
    return player;
  });
  const lands = table.lands.map(({ emoji, color, points }) => ({ emoji, color, points, }));

  const result = Object.assign({}, R.pick([
    'name', 'playerSlots', 'status', 'turnIndex', 'turnStarted', 'gameStart',
  ])(table), {
    players: players_,
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
    position: 0,
    score: 0,
  };
};

const serializePlayer = table => player => {
  return Object.assign({}, R.pick([
    'id', 'name', 'picture', 'color', 'reserveDice', 'out', 'outTurns', 'points', 'level',
  ])(player), { derived: computePlayerDerived(table)(player) });
};
