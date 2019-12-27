import { BotStrategy, BotPlayer, Table, Land, Color } from "../types";

export type Source = { source: Land; targets: Land[] };
export type Attack = { from: Land; to: Land; wheight: number };

export const move = (strategy: BotStrategy) => {
  return (sources: Source[], player: BotPlayer, table: Table) => {
    const lastAgressorColor =
      table.players.find(p => p.id === player.bot.state.lastAgressor)?.color ??
      null;

    return sources.reduce<Attack | null>(
      (attack, { source, targets }) =>
        targets.reduce((attack: Attack, target: Land): Attack => {
          const bestChance = attack ? attack.wheight : -Infinity;

          const result = tactics[strategy](
            bestChance,
            source,
            target,
            lastAgressorColor
          );
          return result ?? attack;
        }, attack),
      null
    );
  };
};

const tactics = {
  ["RandomCareful"]: (bestChance: number, source: Land, target: Land) => {
    const thisChance = source.points - target.points;
    if (thisChance > bestChance) {
      if (thisChance > 0) {
        if (canAttackSucceed(source, target)) {
          return { from: source, to: target, wheight: thisChance };
        }
      }
    }
  },

  ["RandomCareless"]: (bestChance: number, source: Land, target: Land) => {
    const thisChance = source.points - target.points;
    if (thisChance > bestChance) {
      return { from: source, to: target, wheight: thisChance };
    }
  },

  ["Revengeful"]: (
    bestChance: number,
    source: Land,
    target: Land,
    lastAgressorColor: Color | null
  ) => {
    if (lastAgressorColor) {
      if (target.color === lastAgressorColor) {
        const thisChance = source.points - target.points;
        if (thisChance > bestChance) {
          if (canAttackSucceed(source, target)) {
            return { from: source, to: target, wheight: thisChance };
          }
        }
      }
    } else if (target.color === Color.Neutral) {
      const thisChance = source.points - target.points;
      if (thisChance > bestChance) {
        if (thisChance > 1) {
          if (canAttackSucceed(source, target)) {
            return { from: source, to: target, wheight: thisChance };
          }
        }
      }
    }
  },
};

const canAttackSucceed = (from: Land, to: Land) =>
  from.points * 6 > to.points * 1;
