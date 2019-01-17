import * as publish from './publish';
import * as tick from './tick';
import elimination from './elimination';
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  COLOR_NEUTRAL,
  ELIMINATION_REASON_OUT,
  ELIMINATION_REASON_WIN,
} from '../constants';
import { Table } from '../types';
import { update, save } from './get';


const endGame = async (table: Table): Promise<Table> => {
  const winner = table.players[0];
  console.log('game finished', winner);
  await elimination(table, winner, ELIMINATION_REASON_WIN, {
    turns: table.turnCount,
  });

  const newTable = await save(table, {
    status: STATUS_FINISHED,
    turnIndex: -1,
    gameStart: 0,
    turnCount: 1,
    roundCount: 1,
  }, []);
  //tick.stop(table);
  publish.event({
    type: 'end',
    table: newTable.name,
  });
  return newTable;
};
export default endGame;

