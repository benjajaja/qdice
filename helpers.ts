import { createWriteStream, ReadStream } from "fs";
import { pipeline } from "stream";
import * as path from "path";
import * as request from "request";
import * as ps from "promise-streams";
import * as pics from "pics";
import * as resize from "resizer-stream";

import * as R from "ramda";
import { Table, Land, UserId, Player, Elimination, Color } from "./types";
import logger from "./logger";
import { ELIMINATION_REASON_SURRENDER } from "./constants";

pics.use(require("gif-stream"));
pics.use(require("jpg-stream"));
pics.use(require("png-stream"));

export const findTable = <T extends { name: string }>(tables: T[]) => (
  name: string
): T => tables.filter(table => table.name === name).pop()!;

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
  const idLandCounts = table.players.map<[UserId, number, number]>(
    (player, i) => [
      player.id,
      table.lands.filter(R.propEq("color", player.color)).length,
      i,
    ]
  );
  const sorted = R.sortWith(
    [R.descend(R.nth(1)), R.ascend(R.nth(2))],
    idLandCounts
  );

  const positions = sorted.reduce((dict, [id, _, __], i) => {
    dict[id] = i + 1;
    return dict;
  }, {} as { [userId: number]: number });

  return player => positions[player.id] || 0;
};

export const tablePoints = (table: Table): number =>
  table.points === 0 ? 50 : table.points;

export const killPoints = (table: Table): number =>
  Math.floor((table.points === 0 ? 50 : table.points) / 2);

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
        Object.assign(land, { color: Color.Neutral })
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
  elimination: Elimination,
  killPoints: number
): [readonly Player[], readonly Land[], number, readonly Elimination[]] => {
  let [players_, lands_, turnIndex_] = removePlayer(
    players,
    lands,
    player,
    turnIndex
  );
  let eliminations: Elimination[] = [elimination];

  return removeNext([players_, lands_, turnIndex_, eliminations, killPoints]);
};

const removeNext = ([players, lands, turnIndex, eliminations, killPoints]: [
  readonly Player[],
  readonly Land[],
  number,
  readonly Elimination[],
  number
]): [readonly Player[], readonly Land[], number, readonly Elimination[]] => {
  const next = players.find(
    player => player.flag && player.flag === players.length
  );
  if (next) {
    const [players_, lands_, turnIndex_] = removePlayer(
      players,
      lands,
      next,
      turnIndex
    );
    const last = players_.length === 1 ? players_[0] : null;
    return removeNext([
      players_,
      lands_,
      turnIndex_,
      eliminations.concat([
        {
          player: next,
          position: players.length,
          reason: ELIMINATION_REASON_SURRENDER,
          source: {
            flag: next.flag!,
            under: last
              ? {
                  player: last,
                  points: killPoints,
                }
              : null,
          },
        },
      ]),
      killPoints,
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
  return savePicture(filename, stream as any);
};

export const assertNever = (x: never): never => {
  throw new Error("Unexpected value: " + x);
};

export const hasChanged = (lands: readonly Land[]) => (land: Land): boolean => {
  const match = lands.find(R.propEq("emoji", land.emoji));
  if (!match) {
    logger.debug(`did not find ${land.emoji} in lands: ${lands}`);
    return true;
  }
  if (
    land.capital || // always send capital as update to force clients to update it
    land.points !== match.points ||
    land.color !== match.color
  ) {
    return true;
  }
  return false;
};
