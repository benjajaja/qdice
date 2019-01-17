import * as R from 'ramda';
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
import { Table, Land, IllegalMoveError } from '../types';
import { save, update } from './get';

const sitIn = async (user, table: Table, clientId) => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError('sitIn while not STATUS_PLAYING', user);
  }
  const player = table.players.filter(p => p.id === user.id).pop();
  if (!player) {
    throw new IllegalMoveError('sitIn while not in game', user);
  }

  const allOut = table.players.every(R.prop('out'));
  const newTable = update(table, {}, table.players.map(p => p === player
    ? { ...p, out: false, outTurns: 0 }
    : p));
  if (allOut) {
    return await nextTurn(newTable);
  }

  publish.tableStatus(newTable);
  return save(newTable, {});
};
export default sitIn;

