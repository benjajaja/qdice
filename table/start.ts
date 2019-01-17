import * as R from 'ramda';
import { Table, Player, Land } from '../types';
import { update } from './get';
const probe = require('pmx').probe();
import * as publish from './publish';
import { rand } from '../rand';
import {
  STATUS_PLAYING,
} from '../constants';

const startCounter = probe.counter({
  name : 'Games started',
});

const randomPoints = stackSize => {
  const r = Math.random();
  if (r > 0.98)
    return Math.min(8, Math.floor(stackSize / 2 + 1));
  else if (r > 0.90)
    return Math.floor(stackSize / 2);
  return rand(1, Math.floor(stackSize / 4));
};

function shuffle(a) {
  for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

const randomLandOrder = (lands: Land[], playerCount: number) => {
  const landCount = lands.length;
  const colorsCount = landCount - (landCount % playerCount);
  return shuffle(lands.slice()).slice(0, colorsCount);
};

const start = (table: Table): Table => {

  const lands = table.lands.map(land => Object.assign({}, land, {
    points: randomPoints(table.stackSize),
    color: -1,
  }));

  const shuffledLands = randomLandOrder(lands, table.players.length);

  const assignedLands = shuffledLands.map((land, index) => {
    const player = table.players[index % table.players.length];
    land.color = player.color;
    land.points = 1;//randomPoints(table.stackSize);
    return land;
  });
  table.players.forEach(player => {
    const landCount = table.lands.length;
    const colorsCount = landCount - (landCount % table.players.length);
    const playerLandCount = colorsCount / table.players.length;
    R.range(0, playerLandCount).forEach(i => {
      shuffledLands.filter(R.propEq('color', player.color))[i].points = Math.min(table.stackSize, i + 1);
    });
  });
  
  const newTable = update(table, {
    status: STATUS_PLAYING,
    gameStart: Date.now(),
    turnIndex: 0,
    turnStart: Math.floor(Date.now() / 1000),
    turnActivity: false,
    playerStartCount: table.players.length,
  }, undefined, lands);
  publish.event({
    type: 'start',
    table: newTable.name,
  });
  startCounter.inc();
  return newTable;
};
export default start;
