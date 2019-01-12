import * as publish from './publish';
import nextTurn from './turn';
import { hasTurn } from '../helpers';
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} from '../constants';
import { Table, Player, User } from '../types';
import { save, update } from './get';

const sitOut = async (user: User, table: Table, clientId): Promise<Table | undefined> => {
  if (table.status !== STATUS_PLAYING) {
    publish.clientError(clientId, new Error('not playing'));
    return;
  }

  const player = table.players.filter(p => p.id === user.id).pop();
  if (!player) {
    publish.clientError(clientId, new Error('not playing'));
    return;
  }

  const newTable = update(table, {}, table.players.map(p => p === player
    ? { ...p, out: true }
    : p));

  const afterTurnTable = hasTurn(newTable)(player)
    ? await nextTurn(newTable)
    : newTable;
  publish.tableStatus(afterTurnTable);
  return afterTurnTable;
};
export default sitOut;

