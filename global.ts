import * as R from "ramda";
import {
  TURN_SECONDS,
  GAME_START_COUNTDOWN,
  MAX_NAME_LENGTH,
} from "./constants";
import * as publish from "./table/publish";
import { getStatuses } from "./table/get";
import * as db from "./db";
import { death } from "./table/watchers";
import AsyncLock = require("async-lock");

export const global = (version: string) => async (req, res, next) => {
  const tables = await getStatuses();
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
    version,
  });
};

export const findtable = async (req, res, next) => {
  try {
    const tables = await getStatuses();
    let best = tables.reduce(
      (best, table) => (table.playerCount > best.playerCount ? table : best),
      tables[0]
    );
    res.send(200, best.tag);
  } catch (e) {
    next(e);
  }
};

export const onMessage = (lock: AsyncLock) => async (topic, message) => {
  try {
    if (topic === "events") {
      const event = JSON.parse(message);
      switch (event.type) {
        case "join":
        case "leave":
        case "clear":
        case "elimination":
        case "watching":
        case "countdown":
          const tables = await getStatuses();
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
