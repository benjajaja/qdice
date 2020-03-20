import { STATUS_FINISHED, ELIMINATION_REASON_WIN } from "../constants";
import { Table, Player, CommandResult, Elimination } from "../types";
import logger from "../logger";

const endGame = (
  table: Table,
  winner: Player | null,
  turnCount: number
): CommandResult => {
  // const winner = (result.players || table.players)[0];
  logger.info("a game has finished", table.tag);
  const eliminations: Elimination[] = winner
    ? [
        {
          player: winner,
          position: 1,
          reason: ELIMINATION_REASON_WIN,
          source: {
            turns: turnCount,
          },
        },
      ]
    : [];

  return {
    type: "EndGame",
    table: {
      status: STATUS_FINISHED,
      turnIndex: -1,
      gameStart: 0,
      turnCount: 1,
      roundCount: 0,
      currentGame: null,
    },
    players: [] as ReadonlyArray<Player>,
    eliminations,
    retired: [],
  };
};

export default endGame;
