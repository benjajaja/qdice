import * as R from "ramda";
import { Table } from "./types";
import { findTable } from "./helpers";
//import { get } from './table/get';
import {
  TURN_SECONDS,
  GAME_START_COUNTDOWN,
  MAX_NAME_LENGTH,
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
} from "./constants";
import * as publish from "./table/publish";
import { getStatuses } from "./table/get";
import logger from "./logger";

export const global = (req, res, next) => {
  getTablesStatus().then(tables => {
    res.send(200, {
      settings: {
        turnSeconds: TURN_SECONDS,
        gameCountdownSeconds: GAME_START_COUNTDOWN,
        maxNameLength: MAX_NAME_LENGTH,
      },
      tables,
    });
  });
};

export const findtable = (req, res, next) => {
  getTablesStatus().then(tables => {
    let best = tables.reduce(
      (best, table) => (table.playerCount > best.playerCount ? table : best),
      tables[0]
    );
    res.send(200, best.tag);
  });
};

const getTablesStatus = async () => {
  let tables = await getStatuses();
  return R.sortWith<Table & { playerCount: number }>([
    R.descend(R.prop("playerCount")),
    R.ascend(R.prop("name")),
  ])(
    tables.map(table =>
      Object.assign(
        R.pick([
          "name",
          "tag",
          "mapName",
          "stackSize",
          "status",
          "playerSlots",
          "startSlots",
          "landCount",
          "points",
        ])(table),
        {
          playerCount: table.players.length,
          watchCount: table.watching.length,
        }
      )
    )
  ) as any[];
};

export const onMessage = async (topic, message) => {
  try {
    if (topic === "events") {
      const event = JSON.parse(message);
      const tables = await getTablesStatus();
      switch (event.type) {
        case "join": {
          const table = findTable(tables)(event.table);
          if (!table) {
            return;
          }
          //table.players.push(event.player);
          publish.tables(tables);

          return;
        }

        case "leave": {
          const table = findTable(tables)(event.table);
          if (!table) {
            return;
          }
          //table.players = table.players.filter(p => p.id !== event.player.id);
          publish.tables(tables);
          return;
        }

        case "elimination": {
          publish.tables(tables);
          return;
        }

        case "watching": {
          const table = findTable(tables)(event.table);
          if (!table) {
            return;
          }

          //table.watching = event.watching;
          publish.tables(tables);

          return;
        }
      }
    }
  } catch (e) {
    console.error("table list event error", e);
  }
};
