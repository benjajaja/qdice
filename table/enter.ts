import * as R from 'ramda';
import * as publish from './publish';

const enter = async (user, table, clientId) => {
  const existing = R.find(R.propEq('clientId', clientId), table.watching);
  if (!existing) {
    table.watching = R.append({ clientId, name: user ? user.name : null, lastBeat: Date.now() }, table.watching);
    publish.enter(table, user ? user.name : null);
    publish.event({
      type: 'watching',
      table: table.name,
      watching: table.watching.map(R.prop('name')),
    });
  }

  publish.tableStatus(table, clientId);

  if (user) {
    const player = R.find(R.propEq('id', user.id), table.players);
    if (player) {
      if (player.clientId !== clientId) {
        console.log(`player clientId changed ${player.clientId} -> ${clientId}`);
        player.clientId = clientId;
      }
    }
  }
};
export default enter;

