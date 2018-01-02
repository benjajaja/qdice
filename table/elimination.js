const {
  ELIMINATION_REASON_WIN,
} = require('../constants');
const publish = require('./publish');
const { playerPositions, positionScore } = require('../helpers');


module.exports = (table, player, reason, source, points) => {
  const position = reason === ELIMINATION_REASON_WIN
    ? 1
    : table.players.length;

  const score = player.score + positionScore(table.points || 100)(table.playerStartCount)(position);

  console.log('ELIMINATION-------------');
  console.log(position, player);

  publish.elimination(table, player, position, score, {
    type: reason,
    ...source,
  });
};

