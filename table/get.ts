import { UserId, Table, Player, Land } from '../types';
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
    throw new Error("Cannot makeTable without even a tag");
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
  };
};

const loadLands = (table: Table): Table => {
  const [ lands, adjacency ] = maps.loadMap(table.mapName);
  return Object.assign({}, table, {
    lands: table.lands.length ? table.lands : lands,
    adjacency
  });
};


export const getTable = async (tableTag: string): Promise<Table> => {
  let dbTable = await db.getTable(tableTag);
  if (!dbTable) {
    const tableConfig = config.tables.filter(config => config.tag === tableTag).pop();
    const dbTableData = loadLands(makeTable(tableConfig));
    logger.debug('dbTableData', dbTableData);
    dbTable = await db.createTable(dbTableData);
  }
  const table = loadLands(dbTable);
  logger.debug('get', table.turnStart);
  return Promise.resolve(table);
};

export const update = (
  table: Table,
  props: Partial<Table>,
  players?: Player[] | ReadonlyArray<Player>,
  lands?: Land[] | ReadonlyArray<Land>
): Table => {
  let listProps: any = {};
  if (players) {
    listProps.players = players;
  }
  if (lands) {
    listProps.lands = lands;
  }
  const newTable = Object.assign({}, table, props, listProps);
  return newTable;
};

export const save = async (
  table: Table,
  props: Partial<Table>,
  players?: Player[] | ReadonlyArray<Player>,
  lands?: Land[] | ReadonlyArray<Land>
): Promise<Table> => {
  const newTable = update(table, props, players, lands);
  //tables[table.tag] = newTable;
  await db.saveTable(newTable);
  logger.debug('set', new Date(newTable.turnStart * 1000));
  return newTable;
};

export const getStatuses = async () => {
  logger.debug('getStatuses');
  const tables = await db.getTablesStatus();
  logger.debug('gotStatuses');
  const statuses = tables.map(tableStatus => Object.assign(tableStatus, {
    landCount: maps.loadMap(tableStatus.mapName)[0].length,
  }));
  logger.debug('gotStatuses mapped');
  return statuses;
};
