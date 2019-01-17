import {
  ELIMINATION_REASON_WIN,
} from '../constants';
import * as publish from './publish';
import { positionScore, tablePoints } from '../helpers';
import * as db from '../db';
import { Table } from '../types';


const elimination = async (table: Table, player, reason, source) => {
  const position = reason === ELIMINATION_REASON_WIN
    ? 1
    : table.players.length;

  const score = player.score + positionScore(tablePoints(table))(table.playerStartCount)(position);
  publish.elimination(table, player, position, score, {
    type: reason,
    ...source,
  });

  console.log('ELIMINATION-------------');
  console.log(position, player);
  try {
    const user = await db.addScore(player.id, score);
    publish.userUpdate(player.clientId)(user);
  } catch (e) {
    // send a message to this specific player
    publish.clientError(player.clientId, new Error(`You earned ${score} points, but I failed to add them to your profile.`));
    throw e;
  }
};
export default elimination;

