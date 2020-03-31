import * as R from "ramda";

import * as maps from "../maps";
import { groupedPlayerPositions, positionScore, tablePoints } from "../helpers";
import { Table, Player, EliminationReason, EliminationSource } from "../types";
import logger from "../logger";
import { COLOR_NEUTRAL } from "../constants";

export const serializeTable = (table: Table) => {
  const players = table.players.map(serializePlayer(table));

  const lands = table.lands.map(({ emoji, color, points }) => [
    emoji,
    color ?? COLOR_NEUTRAL,
    points ?? 1,
  ]);

  return {
    tag: table.tag,
    name: table.name,
    mapName: table.mapName,
    playerSlots: table.playerSlots,
    startSlots: table.startSlots,
    status: table.status,
    turnIndex: table.turnIndex,
    turnStart: Math.floor(table.turnStart / 1000),
    gameStart: Math.floor(table.gameStart / 1000),
    turnCount: table.turnCount,
    roundCount: table.roundCount,
    players: players,
    lands: lands,
    watchCount: table.watching.length,
    params: table.params,
    currentGame: table.currentGame,
  };
};

export const serializePlayer = (table: Table) => {
  const derived = computePlayerDerived(table);
  return (player: Player) => {
    return Object.assign(
      {},
      R.pick([
        "id",
        "name",
        "picture",
        "color",
        "reserveDice",
        "out",
        "outTurns",
        "points",
        "level",
        "score",
        "flag",
        "ready",
        "awards",
      ])(player),
      { derived: derived(player) }
    );
  };
};

export type PlayerDerived = {
  connectedLands: number;
  totalLands: number;
  currentDice: number;
  position: number;
  score: number;
};

export const computePlayerDerived = (table: Table) => {
  const positions = groupedPlayerPositions(table);
  const getScore =
    table.playerStartCount > 0
      ? positionScore(tablePoints(table))(table.playerStartCount)
      : () => 0;
  return (player: Player): PlayerDerived => {
    const lands = table.lands.filter(R.propEq("color", player.color));
    const connectedLands = maps.countConnectedLands(table)(player.color);
    const position = positions(player);
    if (position === undefined) {
      return {
        connectedLands,
        totalLands: lands.length,
        currentDice: R.sum(lands.map(R.prop("points"))),
        position: 0,
        score: 0,
      };
    }
    let score = player.score + getScore(position);
    if (isNaN(score)) {
      logger.error(`score for ${player.name} isNaN`);
      score = 0;
    }
    return {
      connectedLands,
      totalLands: lands.length,
      currentDice: R.sum(lands.map(R.prop("points"))),
      position,
      score,
    };
  };
};

export const playerWithDerived = (
  table: Table,
  player: Player
): Player & { derived: PlayerDerived } =>
  Object.assign({}, player, {
    derived: computePlayerDerived(table)(player),
  });

export const serializeEliminationReason = (
  table: Table,
  reason: EliminationReason,
  source: EliminationSource
) => {
  let merge = {};
  switch (reason) {
    case "☠":
      merge = {
        player: playerWithDerived(table, (source as any).player),
        points: (source as any).points,
      };
      break;
    case "🏆":
    case "💤":
      merge = {
        turns: (source as any).turns,
      };
      break;
    case "🏳":
      merge = {
        flag: (source as any).flag,
        under:
          (source as any).under === null
            ? null
            : {
                player: playerWithDerived(table, (source as any).under.player),
                points: (source as any).under.points,
              },
      };
      break;
  }
  return { type: reason, ...merge };
};
