const {
  ELIMINATION_REASON_WIN,
} = require('../constants');
const publish = require('./publish');
const { playerPositions, positionScore } = require('../helpers');
const db = require('../db');


module.exports = (table, player, reason, source, points) => {
  const position = reason === ELIMINATION_REASON_WIN
    ? 1
    : table.players.length;

  const score = player.score + positionScore(table.points || 100)(table.playerStartCount)(position);

  console.log('ELIMINATION-------------');
  console.log(position, player);
  db.addScore(player.id, score)
  .then(publish.userUpdate(player.clientId))
  .catch(error => {
    publish.clientError(player.clientId, new Error(`You earned ${score} points, but I failed to add them to your profile.`));
    console.error('error addScore', error);
  });

  publish.elimination(table, player, position, score, {
    type: reason,
    ...source,
  });
};

