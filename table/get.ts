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
    turnStarted: 0,
    turnActivity: false,
    lands: config.lands || [],
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
  if (table.lands.length && table.adjacency.matrix.length) {
    return table;
  }
  logger.info('loadLands', table.lands, table.adjacency);
  const [ lands, adjacency ] = maps.loadMap(table.mapName);
  return Object.assign({}, table, {
    lands: table.lands || lands.map(land => Object.assign({}, land, {
      color: COLOR_NEUTRAL,
      points: 1,
    })),
    adjacency
  });
};

const tables: {[index: string]: Table} = {};

export const getTable = async (tableTag: string): Promise<Table> => {
  if (tables[tableTag]) {
    return tables[tableTag];
  }
  let dbTable = await db.getTable(tableTag);
  if (!dbTable) {
    const tableConfig = config.tables.filter(config => config.tag === tableTag).pop();
    const dbTableData = loadLands(makeTable(tableConfig));
    dbTable = await db.createTable(dbTableData);
  }
  const table = loadLands(makeTable(dbTable));
  tables[tableTag] = table;
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
  console.trace('save');
  logger.info(`save ${table.tag}`);
  const newTable = update(table, props, players, lands);
  tables[table.tag] = newTable;
  await db.saveTable(newTable);
  return newTable;
};

