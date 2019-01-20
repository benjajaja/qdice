import * as publish from './publish';
import * as tick from './tick';
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  COLOR_NEUTRAL,
  ELIMINATION_REASON_OUT,
  ELIMINATION_REASON_WIN,
} from '../constants';
import { Table, Player, CommandResult, Elimination } from '../types';
import logger from '../logger';


const endGame = (table: Table, result: CommandResult): CommandResult => {
  const winner = (result.players || table.players)[0];
  logger.info('a game has finished', table.tag);
  const elimination: Elimination = {
    player: winner,
    position: 1,
    reason: ELIMINATION_REASON_WIN,
    source: {
      turns: result.table && result.table.turnCount
        ? result.table.turnCount
        : table.turnCount,
    }
  };

  return {
    ...result,
    table: {
      ...result.table, 
      status: STATUS_FINISHED,
      turnIndex: -1,
      gameStart: 0,
      turnCount: 1,
      roundCount: 1,
    },
    players: [] as ReadonlyArray<Player>,
    eliminations: (result.eliminations || [] as ReadonlyArray<Elimination>).concat([elimination]),
  };
};

export default endGame;

