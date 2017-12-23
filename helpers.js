
module.exports.findTable = tables => name => tables.filter(table => table.name === name).pop();

module.exports.findLand = lands => emoji => lands.filter(land => land.emoji === emoji).pop();

module.exports.hasTurn = table => playerLike =>
  table.players.indexOf(
    table.players.filter(p => p.id === playerLike.id).pop()
  ) === table.turnIndex;
