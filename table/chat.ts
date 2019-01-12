import * as R from 'ramda';
import * as publish from './publish';

const chat = (user, table, clientId, payload) => {
  publish.chat(table, user ? user.name : null, payload);
};
export default chat;

