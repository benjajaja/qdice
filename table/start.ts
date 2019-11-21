import * as R from 'ramda';
import {Table, Player, Land, CommandResult} from '../types';
import {now} from '../timestamp';
import * as publish from './publish';
import {rand, shuffle} from '../rand';
import logger from '../logger';
import {STATUS_PLAYING} from '../constants';

const randomPoints = stackSize => {
  const r = rand(0, 999) / 1000;
  if (r > 0.98) return Math.min(8, Math.floor(stackSize / 2 + 1));
  else if (r > 0.9) return Math.floor(stackSize / 2);
  return rand(1, Math.floor(stackSize / 4));
};

const start = (table: Table): CommandResult => {
  const lands = R.sort<Land>((a, b) => a.emoji.localeCompare(b.emoji))(
    table.lands,
  ).map(land =>
    Object.assign({}, land, {
      points: randomPoints(table.stackSize),
      color: -1,
    }),
  );

  const shuffledLands = shuffle(lands.slice())
    .slice(0, table.players.length)
    .map(land =>
      Object.assign({}, land, {
        points: randomPoints(table.stackSize),
      }),
    );

  const assignedLands = shuffledLands.map((land, index) => {
    const player = table.players[index % table.players.length];
    return Object.assign({}, land, {color: player.color, points: 4});
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
