import * as R from "ramda";
import logger from "./logger";
import { Adjacency, Land, Emoji, Color, Player } from "./types";

import * as mapJson from "./map-sources.json";

type LimitedTable = {
  lands: ReadonlyArray<Land>;
  adjacency: Adjacency;
};

export const loadMap = (mapName: string): [Land[], Adjacency, string] => {
  const map = mapJson.maps[mapName];
  if (!map) {
    throw new Error(`loadMap: unknown map "${map}"`);
  }
  const { lands, adjacency, name } = map;
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

export const landMasses = (
  table: LimitedTable,
  lands: readonly Land[] = table.lands
) => (color: Color): Emoji[][] => {
  const colorLands: Land[] = lands.filter(R.propEq("color", color));

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

export const countConnectedLands = (
  table: {
    lands: ReadonlyArray<Land>;
    adjacency: Adjacency;
  },
  lands: readonly Land[] = table.lands
) => (color: Color): number => {
  const counts: number[] = landMasses(
    table,
    lands
  )(color).map(R.prop("length"));
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
    return lands.map((land: Land) => {
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

const mapCycle = ["Cepero", "Planeta", "DeLucía", "Montoya", "Sabicas"];
export const nextMap = (map: string) => {
  const index = mapCycle.indexOf(map);
  if (index === -1) {
    logger.error("current map not in mapCycle: " + map);
    return mapCycle[0];
  }
  return mapCycle[index + 1] ?? mapCycle[0];
};
