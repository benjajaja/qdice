import * as R from "ramda";
import { BotStrategy, BotPlayer, Table, Land, Color, Player } from "../types";
import logger from "../logger";
import { landMasses, neighbours } from "../maps";
import { rand } from "../rand";
import { groupedPlayerPositions } from "../helpers";

export type Source = { source: Land; targets: Land[] };
export type Attack = { from: Land; to: Land; wheight: number };

type Tactic = (
  bestChance: number,
  source: Land,
  target: Land,
  player?: BotPlayer,
  table?: Table
) => Attack | undefined;

export const move = (strategy: BotStrategy) => {
  return (
    sources: Source[],
    player: BotPlayer,
    table: Table
  ): Attack | null => {
    const apply = applyTactic(sources, player, table);

    let attack: Attack | null = null;
    if (hasDisconnectedLands(player, table)) {
      attack = apply(tactics.reconnect);
      if (attack) {
        return attack;
      }
    }

    const tactic: Tactic = pickTactic(strategy, player, table);
    return apply(tactic);
  };
};

const applyTactic = (sources: Source[], player: BotPlayer, table: Table) => (
  tactic: Tactic
): Attack | null =>
  sources.reduce<Attack | null>(
    (attack, { source, targets }) =>
      targets.reduce((attack: Attack, target: Land): Attack => {
        const bestChance = attack ? attack.wheight : -Infinity;

        const result = tactic(bestChance, source, target, player, table);
        return result ?? attack;
      }, attack),
    null
  );

export const pickTactic = (
  strategy: BotStrategy,
  player: BotPlayer,
  table: Table
): Tactic => {
  const wouldRefill = wouldRefillAll(player, table);

  const positions = groupedPlayerPositions(table);
  const position = positions(player);
  if (table.roundCount > 3 && !wouldRefill && position === 1) {
    logger.debug(`${player.name} is 1st and extraCareful`);
    return tactics.extraCareful;
  }

  switch (strategy) {
    case "RandomCareless":
      if (rand(0, 100) > 75) {
        return tactics.careful;
      } else {
        return tactics.careless;
      }

    case "Revengeful":
      const lastAgressorColor =
        table.players.find(p => p.id === player.bot.state.lastAgressor)
          ?.color ?? null;

      if (
        table.lands
          .filter(l => l.color === player.color)
          .every(l => l.points === table.stackSize)
      ) {
        return tactics.careless;
      }
      if (table.players.length > 2) {
        return tactics.focusColor(lastAgressorColor ?? Color.Neutral);
      }
      return tactics.careful;

    case "ExtraCareful":
      if (rand(0, 100) > 95 || wouldRefill) {
        return tactics.careless;
      }
      return tactics.extraCareful;

    case "TargetCareful":
      if (rand(0, 100) > 95 || wouldRefill) {
        return tactics.careless;
      }
      return tactics.extraCareful;

    case "RandomCareful":
      if (rand(0, 100) > 95 || wouldRefill) {
        return tactics.careless;
      }
      return tactics.careful;

    default:
      return tactics.careful;
  }
};

export const tactics = {
  careful: (bestChance: number, source: Land, target: Land) => {
    const thisChance = source.points - target.points;
    if (thisChance > bestChance) {
      if (
        thisChance > 0 ||
        (target.color === Color.Neutral && thisChance == 0)
      ) {
        return { from: source, to: target, wheight: thisChance };
      }
    }
  },

  careless: (bestChance: number, source: Land, target: Land) => {
    const thisChance = source.points - target.points;
    if (thisChance > bestChance) {
      return { from: source, to: target, wheight: thisChance };
    }
  },

  focusColor: (color: Color) =>
    function focusColor(bestChance: number, source: Land, target: Land) {
      if (target.color === color) {
        if (color === Color.Neutral) {
          return tactics.careful(bestChance, source, target);
        }
        return tactics.careless(bestChance, source, target);
      }
    },

  reconnect: (
    bestChance: number,
    source: Land,
    target: Land,
    player: BotPlayer,
    table: Table
  ) => {
    const currentCount = landMasses(table)(player.color).length;

    const newTable = {
      ...table,
      lands: table.lands.map(l =>
        l.emoji === target.emoji ? { ...l, color: source.color } : l
      ),
    };

    if (landMasses(newTable)(player.color).length < currentCount) {
      const thisChance = source.points - target.points;
      if (thisChance > bestChance) {
        return { from: source, to: target, wheight: thisChance };
      }
    }
  },

  targetCareful: (
    bestChance: number,
    source: Land,
    target: Land,
    player: BotPlayer,
    table: Table
  ) => {
    const targetNeighboursCarefulness = table.roundCount < 5 ? -1 : 0;
    const remainingPoints = source.points - 1;
    const targetNeighbours = neighbours(table, target).filter(
      land => land.color !== player.color && land.color != Color.Neutral
    );
    if (
      targetNeighbours.length > 0 &&
      targetNeighbours.some(
        land => land.points > remainingPoints + targetNeighboursCarefulness
      )
    ) {
      return;
    }

    const thisChance = source.points - target.points;
    if (thisChance > bestChance) {
      return { from: source, to: target, wheight: thisChance };
    }
  },

  extraCareful: (
    bestChance: number,
    source: Land,
    target: Land,
    player: BotPlayer,
    table: Table
  ) => {
    const targetNeighboursCarefulness = table.roundCount < 5 ? -1 : 0;
    const remainingPoints = source.points - 1;
    const targetNeighbours = neighbours(table, target).filter(
      land => land.color !== player.color && land.color != Color.Neutral
    );
    if (
      targetNeighbours.length > 0 &&
      targetNeighbours.some(
        land => land.points > remainingPoints + targetNeighboursCarefulness
      )
    ) {
      return;
    }
    const sourceNeighbours = neighbours(table, target).filter(
      land =>
        land.color !== player.color &&
        land.color != Color.Neutral &&
        land.emoji !== target.emoji
    );
    if (
      sourceNeighbours.length > 0 &&
      sourceNeighbours.some(land => land.points > 2)
    ) {
      return;
    }
    const thisChance = source.points - target.points;
    if (thisChance > bestChance) {
      return { from: source, to: target, wheight: thisChance };
    }
  },
};

export const hasDisconnectedLands = (player: Player, table: Table): boolean => {
  return landMasses(table)(player.color).length > 1;
};

export const wouldRefillAll = (player: Player, table: Table): boolean => {
  const lands = table.lands.filter(land => land.color === player.color);

  const necessaryDice = lands.reduce((count, land) => {
    return count + (8 - land.points);
  }, 0);
  return lands.length + player.reserveDice >= necessaryDice + 7;
};
