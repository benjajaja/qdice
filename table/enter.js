const R = require('ramda');
const publish = require('./publish');

module.exports = async (user, table, clientId) => {
  console.log('enter', user);
  publish.tableStatus(table, clientId);
  publish.enter(table, user ? user.name : null);
  publish.event({
    type: 'enter',
    table: table.name,
    userId: user ? user.id : null,
  });
  const player = R.find(R.propEq('id', user.id), table.players);
  if (player) {
    if (player.clientId !== clientId) {
      console.log(`player clientId changed ${player.clientId} -> ${clientId}`);
      player.clientId = clientId;
    }
  }
};

