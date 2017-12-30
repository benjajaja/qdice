const probe = require('pmx').probe();
const publish = require('./publish');

const enterCounter = probe.counter({
  name : 'Table enter',
});

module.exports = async (user, table, clientId) => {
  publish.tableStatus(table, clientId);
  publish.enter(table, user.name);
  publish.event({
    type: 'enter',
    table: table.name,
    userId: user.id,
  });
  enterCounter.inc();
};

