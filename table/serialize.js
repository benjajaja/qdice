const R = require('ramda');

const maps = require('../maps');
module.exports.serializeTable = table => {
  const log = baseLog(table.playerStartCount);
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

    const size = table.playerStartCount;
    const position = size - player.derived.position + 1;
    player.derived.score = Math.round(
      R.defaultTo(0)(
        position * ((position + size) / size) - position
      ) * 100
    );
    console.log('score', player.derived.score, size, position);
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
    score: player.score,
  };
};

const serializePlayer = module.exports.serializePlayer = table => player => {
  return Object.assign({}, R.pick([
    'id', 'name', 'picture', 'color', 'reserveDice', 'out', 'outTurns', 'points', 'level',
  ])(player), { derived: computePlayerDerived(table)(player) });
};

const baseLog = x => y => Math.round(Math.log(y) / Math.log(x));
