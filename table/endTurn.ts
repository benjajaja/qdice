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
import { Table, Land, UserLike, IllegalMoveError } from '../types';
import { update, save } from './get';

const endTurn = async (user: UserLike, table: Table, clientId) => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError('endTurn while not STATUS_PLAYING', user);
  }
  if (!hasTurn(table)(user)) {
    throw new IllegalMoveError('endTurn while not having turn', user);
  }

  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    throw new IllegalMoveError('endTurn but did not exist in game', user);
  }

  const newTable = await turn(update(table, { turnActivity: true }));
  publish.tableStatus(newTable);
  return newTable;
};
export default endTurn;

