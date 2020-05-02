import * as R from "ramda";
import logger from "./logger";
import { Adjacency, Land, Emoji, Color } from "./types";

import * as mapJson from "./map-sources.json";
import { shuffle } from "./rand";

type LimitedTable = {
  lands: ReadonlyArray<Land>;
  adjacency: Adjacency;
};

export const loadMap = (mapName: string): [Land[], Adjacency, string] => {
  const { lands, adjacency, name } = mapJson.maps[mapName];
  return [
    lands.map(land => ({ ...land, color: Color.Neutral, points: 0 })),
    adjacency,
    name,
  ];
};

export const isBorder = (
  { indexes, matrix }: Adjacency,
  from: Emoji,
  to: Emoji
): boolean => {
  return matrix[indexes[from]][indexes[to]];
};

export const landMasses = (table: LimitedTable) => (
  color: Color
): Emoji[][] => {
  const colorLands: Land[] = table.lands.filter(R.propEq("color", color));

  const landMasses: Land[][] = colorLands.reduce(
    (masses: Land[][], land: Land): Land[][] => {
      const bordering = masses.filter(mass =>
        mass.some(existing =>
          isBorder(table.adjacency, land.emoji, existing.emoji)
        )
      );

      if (bordering.length === 0) {
        return R.concat(masses)([[land]]);
      }
      return masses
        .map(mass => {
          if (mass === R.head(bordering)) {
            return R.concat(R.concat(mass)([land]))(
              R.unnest(R.tail(bordering))
            );
          } else if (R.tail(bordering).some(R.equals(mass))) {
            return undefined;
          } else {
            return mass;
          }
        })
        .filter(R.identity) as Land[][];
    },
    [] as Land[][]
  );

  return landMasses.map(mass => mass.map(land => land.emoji));
};

export const countConnectedLands = (table: {
  lands: ReadonlyArray<Land>;
  adjacency: Adjacency;
}) => (color: Color): number => {
  const counts: number[] = landMasses(table)(color).map(R.prop("length"));
  return R.reduce(R.max, 0, counts) as number;
};

const isEqualEmojis = (
  target: readonly Land[],
  source: readonly Land[]
): Boolean =>
  target
    .map(l => l.emoji)
    .sort()
    .join("") ===
  source
    .map(l => l.emoji)
    .sort()
    .join("");

/**
 * Return the input lands if config didn't change, or try to copy points and colors to config lands
 */
export const hasChanged = (
  mapName: string,
  dbLands: readonly Land[]
): readonly Land[] => {
  const { lands } = mapJson.maps[mapName];
  if (isEqualEmojis(dbLands, lands)) {
    return dbLands;
  } else {
    logger.warn("lands DID change:", mapName);
    return lands.map(land => {
      const match = dbLands.find(l => l.emoji === land.emoji);
      if (match) {
        return match;
      } else {
        return { emoji: land.emoji, points: 0, color: Color.Neutral };
      }
    });
  }
};

export const neighbours = (table: LimitedTable, land: Land): Land[] => {
  return table.lands.filter(
    other =>
      other.emoji !== land.emoji &&
      isBorder(table.adjacency, other.emoji, land.emoji)
  );
};

const mapCycle = ["Planeta", "Montoya", "DeLucía", "Sabicas", "Cepero"];
export const nextMap = (map: string) => {
  let next = map;
  let fuse = 0;
  while (next === map) {
    next = shuffle(mapCycle)[0];
    fuse += 1;
    if (fuse > 100) {
      logger.error(
        "Tried to shuffle nextMap 100 times and did not get a different result!"
      );
      return next;
    }
  }
  return next;
};
