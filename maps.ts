import * as R from 'ramda';
import { Grid, HEX_ORIENTATIONS } from 'honeycomb-grid';
import logger from './logger';
import { Table, Adjacency, Land, Emoji } from './types';
import { rand } from './rand';
import {
  COLOR_NEUTRAL,
} from './constants';

import * as mapJson from './map-sources.json';

const grid = Grid({
  size: 100,
  orientation: HEX_ORIENTATIONS.POINTY,
});


export const loadMap = (mapName: string): [ Land[], Adjacency, string ] => {
  logger.info(`Loading map: ${mapName}`);
  const { lands, adjacency, name } = mapJson.maps
    .filter(R.propEq('tag', mapName)).pop()!;
  return [ lands.map(land => ({ ...land, color: COLOR_NEUTRAL, points: 0 })), adjacency, name ];
};

export const isBorder = ({ indexes, matrix }: Adjacency, from: Emoji, to: Emoji): boolean => {
  return matrix[indexes[from]][indexes[to]];
};

export const landMasses = (table: Table) => (color: string): Emoji[][] => {
  const colorLands: Land[] = table.lands.filter(R.propEq('color', color));

  const landMasses: Land[][] = colorLands.reduce((masses: Land[][], land: Land): Land[][] => {
    const bordering = masses.filter(mass =>
      mass.some(existing =>
        isBorder(table.adjacency, land.emoji, existing.emoji)));

    if (bordering.length === 0) {
      return R.concat(masses)([ [ land ] ]);
    }
    return masses.map(mass => {
      if (mass === R.head(bordering)) {
        return R.concat(R.concat(mass)([ land ]))(R.unnest(R.tail(bordering)));
      } else if (R.tail(bordering).some(R.equals(mass))) {
        return undefined;
      } else {
        return mass;
      }
    }).filter(R.identity) as Land[][];
  }, [] as Land[][]);

  return landMasses.map(mass =>
    mass.map(land => land.emoji));
};

export const countConnectedLands = (table: Table) => (color: string): number => {
  const counts: number[] = landMasses(table)(color).map(R.prop('length'));
  return R.reduce(R.max, 0, counts) as number;
};

