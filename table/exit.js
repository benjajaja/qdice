const publish = require('./publish');

module.exports = async (user, table, clientId) => {
  publish.exit(table, user ? user.name : null);
  publish.event({
    type: 'exit',
    table: table.name,
    userId: user ? user.id : undefined,
  });
};

