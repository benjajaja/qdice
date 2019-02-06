import * as R from 'ramda';
import { Table, Player, Land, CommandResult } from '../types';
import { now } from '../timestamp';
import * as publish from './publish';
import { rand } from '../rand';
import logger from '../logger';
import {
  STATUS_PLAYING,
} from '../constants';

const randomPoints = stackSize => {
  const r = Math.random();
  if (r > 0.98)
    return Math.min(8, Math.floor(stackSize / 2 + 1));
  else if (r > 0.90)
    return Math.floor(stackSize / 2);
  return rand(1, Math.floor(stackSize / 4));
};

const shuffle = <T>(a: T[]): T[] => {
  for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};

const randomLandOrder = (lands: Land[], playerCount: number): Land[] => {
  const landCount = lands.length;
  const colorsCount = landCount - (landCount % playerCount);
  return shuffle(lands.slice()).slice(0, colorsCount);
};

const start = (table: Table): CommandResult => {
  const lands = table.lands.map(land => Object.assign({}, land, {
    points: randomPoints(table.stackSize),
    color: -1,
  }));

  const shuffledLands = randomLandOrder(lands, table.players.length);

  const assignedLands = shuffledLands.map((land, index) => {
    const player = table.players[index % table.players.length];
    return Object.assign({}, land, { color: player.color, points: 1 });
  });

  table.players.forEach(player => {
    const landCount = table.lands.length;
    const colorsCount = landCount - (landCount % table.players.length);
    const playerLandCount = colorsCount / table.players.length;
    R.range(0, playerLandCount).forEach(i => {
      const land = assignedLands.filter(R.propEq('color', player.color))[i] as any;
      land.points = Math.min(table.stackSize, i + 1);
    });
  });

  const allLands = lands.map(oldLand => {
    const match = assignedLands.filter(l => l.emoji === oldLand.emoji).pop();
    if (match) {
      return match;
    }
    return oldLand;
  });

  return {
    type: 'TickStart',
    table: {
      status: STATUS_PLAYING,
      gameStart: now(),
      turnIndex: 0,
      turnStart: now(),
      turnActivity: false,
      playerStartCount: table.players.length,
    },
    lands: allLands,
  };
};
export default start;
