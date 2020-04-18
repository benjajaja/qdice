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
import * as db from "./db";
import logger from "./logger";
import { death } from "./table/watchers";
import AsyncLock = require("async-lock");

const buildId = process.env.build_id ?? "dev";

export const global = async (req, res, next) => {
  const tables = getStatuses();
  const top = await db.leaderBoardTop(10);
  res.send(200, {
    settings: {
      turnSeconds: TURN_SECONDS,
      gameCountdownSeconds: GAME_START_COUNTDOWN,
      maxNameLength: MAX_NAME_LENGTH,
    },
    tables,
    leaderboard: {
      month: new Date().toLocaleString("en-us", { month: "long" }),
      top,
    },
    version: buildId,
  });
};

export const findtable = (req, res, next) => {
  const tables = getStatuses();
  let best = tables.reduce(
    (best, table) => (table.playerCount > best.playerCount ? table : best),
    tables[0]
  );
  res.send(200, best.tag);
};

export const onMessage = (lock: AsyncLock) => async (topic, message) => {
  try {
    if (topic === "events") {
      const event = JSON.parse(message);
      const tables = getStatuses();
      switch (event.type) {
        case "join":
        case "leave":
        case "clear":
        case "elimination":
        case "watching":
          publish.tables(tables);
          return;
      }
    } else if (topic === "death") {
      death(lock)(message.toString());
    }
  } catch (e) {
    console.error("table list event error", e);
  }
};
