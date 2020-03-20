import { createWriteStream, ReadStream } from "fs";
import { pipeline } from "stream";
import * as path from "path";
import * as request from "request";
import * as ps from "promise-streams";
import * as pics from "pics";
import * as resize from "resizer-stream";

import * as R from "ramda";
import { Table, Land, UserId, Player, Elimination } from "./types";
import logger from "./logger";
import { COLOR_NEUTRAL, ELIMINATION_REASON_SURRENDER } from "./constants";

pics.use(require("gif-stream"));
pics.use(require("jpg-stream"));
pics.use(require("png-stream"));

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
  const removedPlayerIndex = players.indexOf(player);
  const players_ = players.filter(R.complement(R.equals(player)));
  let newTurnIndex: number;
  if (removedPlayerIndex > turnIndex) {
    newTurnIndex = turnIndex;
  } else if (removedPlayerIndex === turnIndex) {
    if (turnIndex >= players_.length) {
      newTurnIndex = 0;
    } else {
      newTurnIndex = turnIndex; // next player
    }
  } else {
    newTurnIndex = turnIndex - 1;
  }
  return [
    players_,
    lands.map(
      R.when(R.propEq("color", player.color), land =>
        Object.assign(land, { color: COLOR_NEUTRAL })
      )
    ),
    newTurnIndex,
  ];
};

export const removePlayerCascade = (
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

export const savePicture = async (filename: string, stream: ReadStream) => {
  const file = createWriteStream(path.join(process.env.AVATAR_PATH!, filename));
  await new Promise((resolve, reject) =>
    pipeline(
      stream,
      pics.decode(),
      resize({ width: 100, height: 100, fit: true, allowUpscale: true }),
      pics.encode("image/gif"),
      file,
      err => (err ? reject(err) : resolve())
    )
  );
  return `${process.env.PICTURE_URL_PREFIX}/${filename}`;
};

export const downloadPicture = async (
  id: UserId,
  url: string | null
): Promise<string | null> => {
  if (url === null) {
    return url;
  }
  const filename = `user_${id}.gif`;
  const stream = request(url);
  return savePicture(filename, stream);
};

export const assertNever = (x: never): never => {
  throw new Error("Unexpected value: " + x);
};
