import { UserId, Table, Player, Land } from '../types';
import * as maps from '../maps.js';
import * as db from '../db';
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} from '../constants';
import * as config from '../tables.config';

const makeTable = (config: any): Table => ({
  name: config.tag,
  tag: config.tag,
  players: [],
  playerSlots: config.playerSlots,
  startSlots: config.startSlots,
  points: config.points,
  status: STATUS_FINISHED,
  gameStart: 0,
  turnIndex: -1,
  turnStarted: 0,
  turnActivity: false,
  lands: [],
  stackSize: config.stackSize,
  playerStartCount: 0,
  turnCount: 1,
  roundCount: 1,
  noFlagRounds: config.noFlagRounds,
  watching: [],
});

const loadLands = (table: Table): Table => {
  const [ lands, adjacency, name ] = maps.loadMap(table.tag);
  return Object.assign({}, table, {
    name,
    lands: lands.map(land => Object.assign({}, land, {
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
  const tableConfig = config.tables.filter(
    config => config.tag === tableTag
  ).pop();
  const table = loadLands(makeTable(tableConfig));
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
  const newTable = update(table, props, players, lands);
  tables[table.tag] = newTable;
  return Promise.resolve(newTable);
};

