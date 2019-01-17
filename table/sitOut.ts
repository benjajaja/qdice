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
import { Table, Player, User, IllegalMoveError } from '../types';
import { save, update } from './get';

const sitOut = async (user: User, table: Table, clientId): Promise<Table | undefined> => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError('sitOut while not STATUS_PLAYING', user);
  }

  const player = table.players.filter(p => p.id === user.id).pop();
  if (!player) {
    throw new IllegalMoveError('sitOut while not in game', user);
  }

  const newTable = update(table, {}, table.players.map(p => p === player
    ? { ...p, out: true }
    : p));

  if (hasTurn(newTable)(player)) {
    return await nextTurn(newTable);
  }

  await save(newTable, {});
  publish.tableStatus(newTable);
  return newTable;
};
export default sitOut;

