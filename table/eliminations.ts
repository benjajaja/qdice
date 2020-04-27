import { Table, Elimination, Player, ScoredElimination } from "../types";
import * as db from "../db";
import * as publish from "./publish";
import { positionScore, tablePoints } from "../helpers";
import { tournamentScore } from "./tournament";

export const processEliminations = async (
  table: Table,
  eliminations: readonly Elimination[],
  players: readonly Player[]
): Promise<void> => {
  const scoredEliminations: readonly ScoredElimination[] = await Promise.all(
    eliminations.map(async elimination => {
      const { player, position } = elimination;

      const score =
        player.score +
        positionScore(tablePoints(table))(table.playerStartCount)(position) +
        tournamentScore(table, position);

      publish.event({
        type: "elimination",
        table: table.name,
        player,
        position,
        score,
      });

      if (player.bot === null) {
        try {
          const user = await db.addScore(player.id, score);
          const preferences = await db.getPreferences(player.id);
          publish.userUpdate(player.clientId)(user, preferences);
        } catch (e) {
          // send a message to this specific player
          publish.clientError(
            player.clientId,
            new Error(
              `You earned ${score} points, but I failed to add them to your profile.`
            )
          );
          throw e;
        }
      }
      return { ...elimination, score };
    })
  );
  if (scoredEliminations.length > 0) {
    publish.eliminations(table, scoredEliminations, players);
  }
  return;
};
