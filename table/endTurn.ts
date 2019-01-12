import * as publish from './publish';
import turn from './turn';
import { hasTurn } from '../helpers';
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} from '../constants';
import { Table, Land, UserLike } from '../types';
import { update, save } from './get';

const endTurn = async (user: UserLike, table: Table, clientId) => {
  if (table.status !== STATUS_PLAYING) {
    return publish.clientError(clientId, new Error('game not running'));
  }
  if (!hasTurn(table)(user)) {
    return publish.clientError(clientId, new Error('out of turn'));
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    return publish.clientError(clientId, new Error('not playing'));
  }

  const newTable = await turn(update(table, { turnActivity: true }));
  publish.tableStatus(newTable);
  return newTable;
};
export default endTurn;

