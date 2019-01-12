import * as R from 'ramda';
import { Table, Adjacency, Land, Emoji } from './types';
import { findTable } from './helpers';
//import { get } from './table/get';
import {
  TURN_SECONDS,
  GAME_START_COUNTDOWN,
  MAX_NAME_LENGTH,
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
} from './constants';
import * as publish from './table/publish';
import * as maps from './maps';

const tablesConfig = require('./tables.config');

const tables = tablesConfig.tables.map(config => {
  const [ lands, adjacency ] = maps.loadMap(config.tag);
  return {
    tag: config.tag,
    name: config.tag,
    playerSlots: config.playerSlots,
    stackSize: config.stackSize,
    points: config.points,
    status: STATUS_PAUSED,
    landCount: lands.length,
    players: [],
    watching: [],
  };
});

export const global = function(req, res, next) {
  res.send(200, {
    settings: {
      turnSeconds: TURN_SECONDS,
      gameCountdownSeconds: GAME_START_COUNTDOWN,
      maxNameLength: MAX_NAME_LENGTH,
    },
    tables: getTablesStatus(tables),
  });
  next();
};

export const findtable = (req, res, next) => {
  res.send(200, R.pipe(
    R.map<any, any>(table => [table.name, table.players.length]),
    R.reduce((R.maxBy as any)(R.nth(1)), ['', -1]),
    R.nth(0),
  )(tables));
};

const getTablesStatus = (tables) =>
  tables.map(table =>
    Object.assign(R.pick([
      'name',
      'tag',
      'stackSize',
      'status',
      'playerSlots',
      'landCount',
      'points',
    ])(table), {
      playerCount: table.players.length,
      watchCount: table.watching.length,
    })
  );

export const onMessage = (topic, message) => {
  try {
    if (topic === 'events') {
      const event = JSON.parse(message);
      switch (event.type) {

        case 'join': {
          const table = findTable(tables)(event.table);
          if (!table) {
            return;
          }
          //table.players.push(event.player);
          publish.tables(getTablesStatus(tables));

          return;
        }

        case 'leave': {
          const table = findTable(tables)(event.table);
          if (!table) {
            return;
          }
          //table.players = table.players.filter(p => p.id !== event.player.id);
          publish.tables(getTablesStatus(tables));
          return;
        }

        case 'elimination': {
          const { player, position, score } = event;
          const table = findTable(tables)(event.table);
          //table.players = table.players.filter(p => p.id === event.player.id);
          publish.tables(getTablesStatus(tables));
          return;
        }

        case 'watching': {
          const table = findTable(tables)(event.table);
          if (!table) {
            return;
          }

          //table.watching = event.watching;
          publish.tables(getTablesStatus(tables));

          return;
        }

      }
    }
  } catch (e) {
    console.error('table list event error', e);
  }
};

