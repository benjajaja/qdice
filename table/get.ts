import * as R from "ramda";
import { UserId, Table, Player, Land, Watcher } from "../types";
import * as maps from "../maps";
import * as db from "../db";
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} from "../constants";
import * as config from "../tables.config";
import logger from "../logger";

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
    roundCount: 0,
    watching: config.watching || [],
    attack: null,
    params: config.params ?? {},
    retired: config.retired || [],
  };
};

export const getTable = async (tableTag: string): Promise<Table> => {
  let dbTable = await db.getTable(tableTag);
  if (!dbTable) {
    const tableConfig = config.tables
      .filter(config => config.tag === tableTag)
      .pop();
    try {
      const [lands, adjacency] = maps.loadMap(tableConfig.mapName);
      const dbTableData = { ...makeTable(tableConfig), lands, adjacency };
      dbTable = await db.createTable(dbTableData);
    } catch (e) {
      logger.error(`could not load map ${tableTag}`);
      throw e;
    }
  }

  const [_, adjacency] = maps.loadMap(dbTable.mapName);
  const table = { ...dbTable, adjacency };

  return table;
};

export const save = async (
  table: Table,
  props?: Partial<Table>,
  players?: readonly Player[],
  lands?: readonly Land[],
  watching?: readonly Watcher[],
  retired?: readonly Player[]
): Promise<Table> => {
  if (props && (props as any).table) {
    throw new Error("bad save");
  }

  if (
    (!props || Object.keys(props).length === 0) &&
    !players &&
    !lands &&
    !watching
  ) {
    console.trace();
    throw new Error("cannot save nothing to table");
  }
  if (retired) {
    logger.debug("retired:", retired);
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
    retired
  );
  return {
    ...table,
    ...saved,
    lands: lands ?? table.lands,
    players: players ?? table.players,
    watching: watching ?? table.watching,
  };
};

export const getStatuses = async () => {
  const tables = await db.getTablesStatus();
  const statuses = tables.map(tableStatus =>
    Object.assign(tableStatus, {
      landCount: maps.loadMap(tableStatus.mapName)[0].length,
    })
  );
  return statuses;
};
