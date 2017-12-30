const probe = require('pmx').probe();
const publish = require('./publish');

const enterCounter = probe.counter({
  name : 'Table enter',
});

module.exports = async (user, table, clientId) => {
  console.log('enter', user);
  publish.tableStatus(table, clientId);
  publish.enter(table, user ? user.name : null);
  publish.event({
    type: 'enter',
    table: table.name,
    userId: user ? user.id : null,
  });
  enterCounter.inc();
};

