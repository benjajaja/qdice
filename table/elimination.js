const {
  ELIMINATION_REASON_WIN,
} = require('../constants');
const publish = require('./publish');


module.exports = (table, player, reason, source) => {
  const position = reason === ELIMINATION_REASON_WIN
    ? 1
    : table.players.length;

  publish.elimination(table, player, position, {
    type: reason,
    source,
  });
};

