const publish = require('./publish');

module.exports = async (user, table, clientId) => {
  publish.exit(table, user.name);
  publish.event({
    type: 'exit',
    table: table.name,
    userId: user.id,
  });
};

