import * as R from 'ramda';
import {UserId, Table, Player, Land, Watcher} from '../types';
import * as maps from '../maps';
import * as db from '../db';
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} from '../constants';
import * as config from '../tables.config';
import logger from '../logger';

const makeTable = (config: any): Table => {
  if (!config.tag) {
    throw new Error('Cannot makeTable without even a tag');
  }
  return {
    name: config.name,
    tag: config.tag,
    mapName: config.mapName,
    players: config.players || [],
    playerSlots: config.playerSlots,
    startSlots: config.startSlots,
    points: config.points,
    status: STATUS_FINISHED,
    gameStart: 0,
    turnIndex: -1,
    turnStart: 0,
    turnActivity: false,
    lands: [],
    adjacency: {
      matrix: [],
      indexes: {},
    },
    stackSize: config.stackSize,
    playerStartCount: 0,
    turnCount: 1,
    roundCount: 1,
    noFlagRounds: config.noFlagRounds,
    watching: config.watching || [],
    attack: null,
  };
};

const loadLands = (table: Table): Table => {
  const [lands, adjacency] = maps.loadMap(table.mapName);
  return Object.assign({}, table, {
    lands: table.lands.length
      ? table.lands.map(land => {
          const match = lands.filter(l => l.emoji === land.emoji).pop();
          if (!match) {
            throw new Error('cannot get land: ' + table.mapName);
          }
          return Object.assign({}, match, land);
        })
      : lands,
    adjacency,
  });
};

export const getTable = async (tableTag: string): Promise<Table> => {
  let dbTable = await db.getTable(tableTag);
  if (!dbTable) {
    const tableConfig = config.tables
      .filter(config => config.tag === tableTag)
      .pop();
    try {
      const dbTableData = loadLands(makeTable(tableConfig));
      dbTable = await db.createTable(dbTableData);
    } catch (e) {
      logger.error(`could not load map ${tableTag}`);
      throw e;
    }
  }
  const table = loadLands(dbTable);

  //if (table.tag === 'Arabia') {
  //const players = R.range(0, 9).map(i => {
  //return table.players[i] || Object.assign({}, R.last(table.players), {
  //color: i + 1,
  //name: 'fake' + i,
  //});
  //});
  //return Object.assign({}, table, { players });
  //}
  return table;
};

export const save = async (
  table: Table,
  props?: Partial<Table>,
  players?: Player[] | ReadonlyArray<Player>,
  lands?: Land[] | ReadonlyArray<Land>,
  watching?: Watcher[] | ReadonlyArray<Watcher>,
): Promise<Table> => {
  if (props && (props as any).table) {
    throw new Error('bad save');
  }
  if (lands && lands.length !== table.lands.length) {
    throw new Error('lost lands');
  }
  if (
    lands &&
    (lands as any).some(land => {
      return lands.filter(other => other.emoji === land.emoji).length !== 1;
    })
  ) {
    logger.debug(lands.map(l => l.emoji));
    throw new Error('duped lands');
  }
  if (
    (!props || Object.keys(props).length === 0) &&
    !players &&
    !lands &&
    !watching
  ) {
    console.trace();
    throw new Error('cannot save nothing to table');
  }
  const saved = await db.saveTable(
    table.tag,
    props,
    players,
    lands
      ? lands.map(land => ({
          emoji: land.emoji,
          color: land.color,
          points: land.points,
        }))
      : undefined,
    watching,
  );
  return loadLands(saved);
};

export const getStatuses = async () => {
  const tables = await db.getTablesStatus();
  const statuses = tables.map(tableStatus =>
    Object.assign(tableStatus, {
      landCount: maps.loadMap(tableStatus.mapName)[0].length,
    }),
  );
  return statuses;
};
