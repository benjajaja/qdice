const R = require('ramda');

module.exports.findTable = tables => name => tables.filter(table => table.name === name).pop();

module.exports.findLand = lands => emoji => lands.filter(land => land.emoji === emoji).pop();

module.exports.hasTurn = table => playerLike =>
  table.players.indexOf(
    table.players.filter(p => p.id === playerLike.id).pop()
  ) === table.turnIndex;

const scoreStep = 10;
module.exports.positionScore = multiplier => gameSize => position => {
  const invPos = gameSize - position + 1;
  return R.pipe(
    factor => factor * multiplier / scoreStep / gameSize,
    Math.round,
    R.multiply(scoreStep),
    R.defaultTo(0),
  )(
      ((invPos * (invPos / gameSize)) - (gameSize / 2)) * 2
  );
};

module.exports.groupedPlayerPositions = table => {
  const positions = R.pipe(
    R.map(player => [
      player.id,
      table.lands.filter(R.propEq('color', player.color)).length,
    ]),
    R.sortBy(R.nth(1)),
    R.reverse,
  )(table.players)
  .map(([id, count], i) => [id, count, i + 1])
  .reduce((acc, [id, landCount, position], i) => {
    return R.append(i > 0 && acc[i - 1][1] === landCount
      ? [id, landCount, acc[i - 1][2]]
      : [id, landCount, position])(acc);
  }, []);
  
  return player => R.find(R.propEq(0, player.id), positions)[2];
};


module.exports.playerPositions = table => {
  //const positions = R.sort((a, b) => {
  //})(table.players)
  //.map((player, index) => [player.id, index + 1]);

  return player => R.find(R.propEq(0, player.id), positions)[1];
};

