import * as R from "ramda";
import { Table, Player, Land, Watcher, TableInfo, Chatter } from "../types";
import * as maps from "../maps";
import * as Sentry from "@sentry/node";
import { STATUS_FINISHED } from "../constants";
import * as config from "../tables.config";
import logger from "../logger";
import { isBot } from "./bots";
import AsyncLock = require("async-lock");
import { createHandyClient } from "handy-redis";
import { tableStatus } from "./publish";

const redis = createHandyClient({
  host: process.env.REDIS_HOST,
});

let memoryTables: { [tag: string]: Table } = {};

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
    currentGame: null,
  };
};

export const getTable = async (tableTag: string): Promise<Table> => {
  if (memoryTables[tableTag] && Math.random() > 0.01) {
    return memoryTables[tableTag];
  }
  try {
    const str = await redis.hget("tables", tableTag);
    const table = JSON.parse(str!);

    if (memoryTables[tableTag]) {
      if (!R.equals(memoryTables[tableTag], table)) {
        logger.error("cache diff error");
        const memTable = memoryTables[tableTag];
        if (Object.keys(memTable).length !== Object.keys(table).length) {
          logger.debug(`${Object.keys(memTable)} vs ${Object.keys(table)}`);
        } else {
          for (const key in memTable) {
            if (!R.equals(memTable[key], table[key])) {
              logger.debug(`diff key ${key}`);
            }
          }
        }
        Sentry.captureException(new Error("DB/Memory inconsistent"));
        Sentry.captureEvent({
          message: "CacheError",
          extra: {
            memory: memoryTables[tableTag],
            db: table,
          },
        });
      }
    }

    if (typeof table !== "object" || table === null) {
      throw new Error("bad saved table: " + table);
    }

    return table;
  } catch (e) {
    logger.debug("table get failed", tableTag, e.toString());
    try {
      const tableConfig = config.tables.find(config => config.tag === tableTag);
      const [lands, adjacency] = maps.loadMap(tableConfig.mapName);
      const table = {
        ...makeTable(tableConfig),
        lands: lands.map(R.omit(["cells"])),
        adjacency,
      };
      logger.debug("recreated table", tableTag);
      await redis.hset("tables", tableTag, JSON.stringify(table));
      memoryTables[tableTag] = table;
      logger.debug("table SET", tableTag);
      return table;
    } catch (e) {
      logger.error("Could not create fresh table");
      throw e;
    }
  }
};

export const save = async (
  table: Table,
  props?: Partial<Table>,
  players?: readonly Player[],
  lands?: readonly Land[],
  watching?: readonly Watcher[],
  retired?: readonly Player[]
): Promise<Table> => {
  try {
    const newTable = {
      ...table,
      ...props,
      players: players ?? table.players,
      lands: lands ?? table.lands,
      watching: watching ?? table.watching,
      retired: retired ?? table.retired,
    };
    const str = JSON.stringify(newTable);
    if (typeof str !== "string") {
      throw new Error("could not stringify table: " + table.tag);
    }
    if (typeof table.tag !== "string") {
      throw new Error("table has no tag: " + table.name);
    }
    await redis.hset("tables", table.tag, str);
    memoryTables[table.tag] = newTable;
    return newTable;
  } catch (e) {
    logger.error("redis table SET", e);
    throw e;
  }
};

export const getStatuses = async (): Promise<readonly TableInfo[]> => {
  const tables: Table[] = await Promise.all(
    config.tables.map(t => getTable(t.tag))
  );

  return R.sortWith(
    [
      R.ascend(R.prop("name")),
      // R.descend(R.prop("playerCount")),
      // R.descend(R.prop("watchCount")),
    ],
    tables
      // .filter(table => !table.params.twitter)
      .map(table => ({
        ...R.omit(["lands", "players", "watchers", "adjacency"], table),
        landCount: table.lands.length,
        playerCount: table.players.length,
        watchCount: table.watching.length,
        botCount: table.players.filter(isBot).length,
      }))
  );
};

export const addChat = async (table: Table, user: Chatter, message: string) => {
  await redis.lpush(
    "chatlines-" + table.tag,
    JSON.stringify({ user, message })
  );
  await redis.ltrim("chatlines-" + table.tag, 0, 99);
};

export const getChat = async (table: Table) => {
  const raw = await redis.lrange("chatlines-" + table.tag, 0, 99);
  return raw.reverse().map(str => JSON.parse(str));
};

export const clearGames = async (lock: AsyncLock): Promise<void> => {
  lock.acquire([config.tables.map(table => table.name)], async done => {
    await redis.del("tables");
    memoryTables = {};
    for (const table of config.tables) {
      const newTable = await getTable(table.name);
      tableStatus(newTable);
    }
    logger.debug("E2E cleared all tables");
    done();
  });
};

export const getTableTags = async () => {
  const tags = await redis.hkeys("tables");
  return tags;
};

export const deleteTable = async (tag: string) => {
  await redis.hdel("tables", tag);
};
