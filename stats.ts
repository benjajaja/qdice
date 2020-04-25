import { Player, PlayerStats } from "./types";
import * as db from "./db";
import logger from "./logger";

export const addStats = async (
  player: Player,
  fn: (input: PlayerStats) => PlayerStats
) => {
  const stats = await db.userStats(player.id);
  const stats_ = fn(stats);
  logger.debug("stats", stats_);
  return await db.updateUserStats(player.id, stats_);
};

export const addRolls = async (player: Player, roll: number[]) => {
  await addStats(player, stats => {
    const rolls = stats.rolls ?? [0, 0, 0, 0, 0, 0];
    const rolls_ = roll.reduce((rolls, die) => {
      rolls[die - 1] = (rolls[die - 1] ?? 0) + 1;
      return rolls;
    }, rolls);
    return { ...stats, rolls: rolls_ };
  });
};
