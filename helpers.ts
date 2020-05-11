import { createWriteStream, ReadStream } from "fs";
import { pipeline } from "stream";
import * as path from "path";
import * as request from "request";
import * as ps from "promise-streams";
import * as pics from "pics";
import * as resize from "resizer-stream";
import * as crop from "crop-image-stream";

import * as R from "ramda";
import {
  Table,
  Land,
  UserId,
  Player,
  Elimination,
  Color,
  Emoji,
} from "./types";
import * as maps from "./maps";
import logger from "./logger";
import { ELIMINATION_REASON_SURRENDER } from "./constants";
import { rand, shuffle } from "./rand";

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

type LimitedPlayer = { id: string; color: number };
type LimitedLand = { color: number };
export const groupedPlayerPositions = (
  table: {
    players: readonly LimitedPlayer[];
    lands: readonly LimitedLand[];
  },
  lands: readonly LimitedLand[] = table.lands,
  players: readonly LimitedPlayer[] = table.players
): ((player: { id: string; color: number }) => number) => {
  const idLandCounts = players.map<[UserId, number, number]>((player, i) => [
    player.id,
    lands.filter(R.propEq("color", player.color)).length,
    i,
  ]);
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

type Rect = { width: number; height: number };
type Point = { x: number; y: number };
export type CropData = {
  size: Rect;
  crop: Rect;
  resized: Rect;
  origin: Point;
};
export const savePicture = async (
  filename: string,
  stream: ReadStream,
  cropData?: CropData
) => {
  const file = createWriteStream(path.join(process.env.AVATAR_PATH!, filename));
  await new Promise((resolve, reject) =>
    cropData
      ? pipeline(
          stream,
          pics.decode(),
          resize({
            width: cropData.resized.width,
            height: cropData.resized.height,
            fit: false,
            allowUpscale: true,
          }),
          crop({
            x: cropData.origin.x,
            y: cropData.origin.y,
            width: 100,
            height: 100,
          }),
          pics.encode("image/gif"),
          file,
          err => (err ? reject(err) : resolve())
        )
      : pipeline(
          stream,
          pics.decode(),
          resize({
            width: 100,
            height: 100,
            fit: true,
            allowUpscale: true,
          }),
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

export const giveDice = (
  table: Table
): {
  lands: readonly [Emoji, number][];
  reserve: number;
  capitals: readonly Emoji[];
} => {
  const player = table.players[table.turnIndex];
  const connectLandCount = maps.countConnectedLands({
    lands: table.lands,
    adjacency: table.adjacency,
  })(player.color);
  const newDies = connectLandCount + player.reserveDice;

  let reserve = 0;

  let lands: readonly Land[] = table.lands.slice();
  let result: [Emoji, number][] = [];
  R.range(0, newDies).forEach(i => {
    const targets = lands.filter(
      land => land.color === player.color && land.points < table.stackSize
    );
    if (targets.length === 0) {
      reserve += 1;
    } else {
      let target: Land;
      if (i >= connectLandCount) {
        target =
          targets.find(R.propEq("capital", true)) ??
          targets[rand(0, targets.length - 1)];
      } else {
        target = targets[rand(0, targets.length - 1)];
      }
      lands = updateLand(lands, target, { points: target.points + 1 });
      if (lands.some(land => land.points > 8)) {
        logger.error("giveDice gave too much dice!");
      }
      result = result.find(([emoji, _]) => emoji === target.emoji)
        ? result.map(([emoji, count]) =>
            emoji === target.emoji ? [emoji, count + 1] : [emoji, count]
          )
        : [...result, [target.emoji, 1]];
    }
  });

  let capitals: readonly Emoji[] = [];
  if (table.params.startingCapitals) {
    capitals = table.players.reduce((result: Emoji[], { color }) => {
      const playerLands = table.lands.filter(R.propEq("color", color));
      if (playerLands.every(R.propEq("capital", false))) {
        logger.debug(`giving new capital to #${color}`);
        const match = R.sortWith(
          [R.ascend(R.prop("points"))],
          shuffle(playerLands)
        ).pop();
        if (match) {
          return [...result, match.emoji];
        } else {
          logger.error(`#${color} has no capital but I can't find it again!`);
        }
      }
      return result;
    }, []);
  }
  return { lands: result, reserve, capitals };
};

export const getPreviousPlayer = (table: Table) => {
  if (table.turnIndex === 0) {
    return R.last(table.players);
  }
  return table.players[table.turnIndex - 1];
};
