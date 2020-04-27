import * as R from "ramda";

import * as maps from "../maps";
import { groupedPlayerPositions, positionScore, tablePoints } from "../helpers";
import {
  Table,
  Player,
  EliminationReason,
  EliminationSource,
  Color,
  Land,
  TournamentFrequency,
} from "../types";
import logger from "../logger";

export const serializeTable = (table: Table) => {
  const players = table.players.map(serializePlayer(table));

  const lands = table.lands.map(serializeLand(table.players));

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
    params: {
      ...table.params,
      tournament: table.params.tournament
        ? mapParamsTournament(table.params.tournament)
        : undefined,
    },
    currentGame: table.currentGame,
  };
};

export const serializeLand = (players: readonly Player[]) => ({
  emoji,
  color,
  points,
  capital,
}: Land): [string, Color, number, number] => {
  if (color !== Color.Neutral && capital) {
    const extraDice = players.find(R.propEq("color", color))?.reserveDice;
    if (extraDice === undefined) {
      logger.error("serializeLand capital has not found its player!");
    }
    return [emoji, color ?? Color.Neutral, points ?? 1, extraDice ?? -1];
  } else {
    return [emoji, color ?? Color.Neutral, points ?? 1, -1];
  }
};

export const serializePlayer = (
  table: Table
): ((p: Player) => SerializedPlayer) => {
  const derived = computePlayerDerived(table);
  return (player: Player) => {
    return {
      ...trimPlayer(player),
      derived: derived(player),
    };
  };
};

export const trimPlayer = (player: Player) => {
  return R.pick(
    [
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
    ],
    player
  );
};

export type SerializedPlayer = Pick<
  Player,
  | "id"
  | "name"
  | "picture"
  | "color"
  | "reserveDice"
  | "out"
  | "outTurns"
  | "points"
  | "level"
  | "score"
  | "flag"
  | "ready"
  | "awards"
> & { derived: PlayerDerived };

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
  let ser = serializePlayer(table);
  let merge = {};
  switch (reason) {
    case "☠":
      merge = {
        player: ser(playerWithDerived(table, (source as any).player)),
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
                player: ser(
                  playerWithDerived(table, (source as any).under.player)
                ),
                points: (source as any).under.points,
              },
      };
      break;
  }
  return { type: reason, ...merge };
};

export const serializeGame = game => ({
  ...game,
  players: game.players
    .map(R.pick(["id", "name", "picture", "color", "bot"]))
    .map(p => ({
      ...p,
      bot: !!p.bot,
    })),
  events: (game.events ?? [])
    .map(event => ({ ...event.params, id: event.id }))
    .filter(params => Object.keys(params).length > 0),
  lands: (game.lands ?? []).map(land => [
    land.emoji,
    land.color,
    land.points,
    land.capital ? 0 : -1,
  ]),
});

const mapParamsTournament = (tournament: {
  frequency: TournamentFrequency;
}) => {
  return { ...tournament };
};
