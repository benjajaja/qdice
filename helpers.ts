import * as R from "ramda";
import { Table, Land, UserId, Player, Elimination } from "./types";
import logger from "./logger";
import { COLOR_NEUTRAL, ELIMINATION_REASON_SURRENDER } from "./constants";

export const findTable = (tables: Table[]) => (name: string): Table =>
  tables.filter(table => table.name === name).pop()!;

export const findLand = (lands: ReadonlyArray<Land>) => (emoji: string): Land =>
  lands.filter(land => land.emoji === emoji).pop()!;

export const hasTurn = ({
  turnIndex,
  players,
}: {
  turnIndex: number;
  players: ReadonlyArray<Player>;
}) => (playerLike: { id: UserId }): boolean =>
  players.indexOf(players.filter(p => p.id === playerLike.id).pop()!) ===
  turnIndex;

const scoreStep = 10;
export const positionScore = (multiplier: number) => (gameSize: number) => (
  position: number
): number => {
  const invPos = gameSize - position + 1;
  const factor = (invPos * (invPos / Math.max(0, gameSize)) - gameSize / 2) * 2;
  const baseScore = Math.round(
    (factor * multiplier) / scoreStep / Math.max(0, gameSize)
  );
  const score = baseScore * scoreStep;
  if (JSON.stringify(score) !== `${score}`) {
    logger.error(
      `bad score for position:${position} gameSize:${gameSize} multiplier:${multiplier}:`,
      score
    );
    logger.debug("invPos", invPos);
    logger.debug("factor", factor);
    logger.debug("baseScore", baseScore);
    return 0;
  }
  return score;
};

export const groupedPlayerPositions = (table: {
  players: ReadonlyArray<{ id: string; color: number }>;
  lands: ReadonlyArray<{ color: number }>;
}): ((player: { id: string; color: number }) => number) => {
  const idLandCounts = table.players.map<[UserId, number]>(player => [
    player.id,
    table.lands.filter(R.propEq("color", player.color)).length,
  ]);
  const sorted = R.sortBy(([_, count]) => count)(idLandCounts);
  const reversed = R.reverse(sorted);

  const positions = reversed.reduce((dict, [id, landCount], i) => {
    dict[id] = i + 1;
    return dict;
  }, {} as { [userId: number]: number });

  return player => positions[player.id] || 0;
};

export const tablePoints = (table: Table): number =>
  table.points === 0 ? 50 : table.points;

export const updateLand = (
  lands: ReadonlyArray<Land>,
  target: Land,
  props: Partial<Land>
): ReadonlyArray<Land> => {
  return lands.map(land => {
    if (land.emoji !== target.emoji) {
      return land;
    }
    return { ...land, ...props };
  });
};

export const adjustPlayer = R.curry(
  (index: number, props: Partial<Player>, players: ReadonlyArray<Player>) =>
    R.adjust(player => ({ ...player, ...props }), index, players)
);

export const removePlayer = (
  players: readonly Player[],
  lands: readonly Land[],
  player: Player,
  turnIndex: number
): [readonly Player[], readonly Land[], number] => {
  const turnPlayer = players[turnIndex];
  const players_ = players.filter(R.complement(R.equals(player)));
  return [
    players_,
    lands.map(
      R.when(R.propEq("color", player.color), land =>
        Object.assign(land, { color: COLOR_NEUTRAL })
      )
    ),
    turnPlayer !== player
      ? players_.indexOf(turnPlayer)
      : turnIndex === players_.length
      ? 0
      : turnIndex,
  ];
};

export const removePlayerCascade = (
  table: Table,
  players: readonly Player[],
  lands: readonly Land[],
  player: Player,
  turnIndex: number,
  elimination: Elimination
): [readonly Player[], readonly Land[], number, readonly Elimination[]] => {
  let [players_, lands_, turnIndex_] = removePlayer(
    players,
    lands,
    player,
    turnIndex
  );
  let eliminations: Elimination[] = [elimination];

  return removeNext([players_, lands_, turnIndex_, eliminations]);
};

const removeNext = ([players, lands, turnIndex, eliminations]: [
  readonly Player[],
  readonly Land[],
  number,
  readonly Elimination[]
]): [readonly Player[], readonly Land[], number, readonly Elimination[]] => {
  const next = players.find(
    player => player.flag && player.flag === players.length
  );
  if (next) {
    const [a, b, c] = removePlayer(players, lands, next, turnIndex);
    return removeNext([
      a,
      b,
      c,
      eliminations.concat([
        {
          player: next,
          position: players.length,
          reason: ELIMINATION_REASON_SURRENDER,
          source: {
            flag: next.flag!,
          },
        },
      ]),
    ]);
  }
  return [players, lands, turnIndex, eliminations];
};
