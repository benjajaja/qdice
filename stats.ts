import * as R from "ramda";
import { Player, PlayerStats } from "./types";
import * as db from "./db";
import logger from "./logger";

export const addStats = async (
  player: Player,
  fn: (input: PlayerStats) => PlayerStats
) => {
  const stats = await db.userStats(player.id);
  const stats_ = fn(stats);
  // logger.debug("stats", stats_);
  return await db.updateUserStats(player.id, stats_);
};

export const addRoll = async (
  attacker: Player,
  fromRoll: number[],
  defender: Player | null,
  toRoll: number[]
) => {
  if (!attacker.bot) {
    await addStats(attacker, stats => {
      return {
        ...stats,
        rolls: addRolls(stats.rolls, fromRoll),
        attacks: addAttacks(stats.attacks, R.sum(fromRoll) > R.sum(toRoll)),
      };
    });
  }
  if (defender && !defender.bot) {
    await addStats(defender, stats => {
      return { ...stats, rolls: addRolls(stats.rolls, toRoll) };
    });
  }
};

export const addElimination = async (player: Player, position) => {
  await addStats(player, stats => {
    const eliminations = stats.eliminations ?? [0, 0, 0, 0, 0, 0, 0, 0, 0];
    eliminations[position - 1] = eliminations[position - 1] + 1;
    return { ...stats, eliminations };
  });
};

export const addKill = async (player: Player) => {
  await addStats(player, stats => {
    const kills = (stats.kills ?? 0) + 1;
    return { ...stats, kills };
  });
};

const addRolls = (
  rolls: [number, number, number, number, number, number] | undefined = [
    0,
    0,
    0,
    0,
    0,
    0,
  ],
  roll: number[]
) => {
  return roll.reduce((rolls, die) => {
    rolls[die - 1] = (rolls[die - 1] ?? 0) + 1;
    return rolls;
  }, rolls);
};

const addAttacks = (
  attacks: [number, number] | undefined = [0, 0],
  success: boolean
): [number, number] => {
  return success ? [attacks[0] + 1, attacks[1]] : [attacks[0], attacks[1] + 1];
};
