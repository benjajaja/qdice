const R = require('ramda');
const publish = require('./publish');

module.exports = (user, table, clientId) => {
  const existing = R.find(R.propEq('clientId', clientId), table.watching);
  if (existing) {
    existing.lastBeat = Date.now();
  } else {
    table.watching = R.append({ clientId, name: user ? user.name : null, lastBeat: Date.now() }, table.watching);

    publish.event({
      type: 'watching',
      table: table.name,
      watching: table.watching.map(R.prop('name')),
    });
  }
};


