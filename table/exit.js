const R = require('ramda');
const publish = require('./publish');

module.exports = async (user, table, clientId) => {
  publish.exit(table, user ? user.name : null);
  table.watching = R.filter(R.complement(R.propEq('clientId', clientId)), table.watching);
  publish.event({
    type: 'watching',
    table: table.name,
    watching: table.watching.map(R.prop('name')),
  });
};

