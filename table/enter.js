const probe = require('pmx').probe();
const publish = require('./publish');

const enterCounter = probe.counter({
  name : 'Table enter',
});
module.exports = (user, table, clientId, res, next) => {
  publish.tableStatus(table, clientId);
  enterCounter.inc();
  res.send(204);
  next();
};

