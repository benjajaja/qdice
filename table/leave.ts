import * as publish from './publish';
import * as tick from './tick';
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} from '../constants';
import { Table, Player, User } from '../types';
import { save } from './get';

const leave = async (user: User, table: Table, clientId): Promise<Table | undefined> => {
  if (table.status === STATUS_PLAYING) {
    publish.clientError(clientId, new Error('already started'));
    return;
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    publish.clientError(clientId, new Error('not joined'));
    return;
  }

  const players = table.players.filter(p => p !== existing);

  const gameStart = players.length >= 2 && Math.ceil(table.playerSlots / 2) <= table.players.length
    ? Math.floor(Date.now() / 1000) + GAME_START_COUNTDOWN
    : 0;

  const status = table.players.length === 0 && table.status === STATUS_PAUSED
    ? STATUS_FINISHED
    : table.status;

  const coloredPlayers = players.map((player, index) => Object.assign(player, { color: index + 1 }));

  const newTable = await save(table, { gameStart, status }, coloredPlayers);
  publish.tableStatus(newTable);
  publish.event({
    type: 'leave',
    table: newTable.name,
    player: existing,
  });
  return newTable;
};
export default leave;

