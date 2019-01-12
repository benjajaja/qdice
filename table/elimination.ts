import {
  ELIMINATION_REASON_WIN,
} from '../constants';
import * as publish from './publish';
import { positionScore, tablePoints } from '../helpers';
import * as db from '../db';
import { Table } from '../types';


const elimination = (table: Table, player, reason, source) => {
  const position = reason === ELIMINATION_REASON_WIN
    ? 1
    : table.players.length;

  const score = player.score + positionScore(tablePoints(table))(table.playerStartCount)(position);

  console.log('ELIMINATION-------------');
  console.log(position, player);
  db.addScore(player.id, score)
  .then(publish.userUpdate(player.clientId))
  .catch(error => {
    publish.clientError(player.clientId, new Error(`You earned ${score} points, but I failed to add them to your profile.`));
    console.error('error addScore', error);
  });

  publish.elimination(table, player, position, score, {
    type: reason,
    ...source,
  });
};
export default elimination;

