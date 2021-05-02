import * as R from "ramda";
import {
  TURN_SECONDS,
  GAME_START_COUNTDOWN,
  MAX_NAME_LENGTH,
} from "./constants";
import { User } from "./types";
import * as publish from "./table/publish";
import { getStatuses } from "./table/get";
import * as db from "./db";
import { death } from "./table/watchers";
import AsyncLock = require("async-lock");
import { promisify } from "util";
import * as jwt from "jsonwebtoken";

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

export const onMessage = (lock: AsyncLock) => async (topic: string, message: string) => {
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
    } else if (topic === "hello") {
      await onHello(JSON.parse(message));
    }
  } catch (e) {
    console.error("table list event error", e);
  }
};

const verifyJwt = promisify(jwt.verify);
const oneDay = 24 * 60 * 60 * 1000;
const DAILY_BONUS_POINTS = 100;
const WEEKLY_BONUS_POINTS = 500;
const onHello = async ({ client, token }: { client: string, token: string }) => {
  if (!client) {
    return console.error("onHello: no client");
  }

  const token_user = (await verifyJwt(token, process.env.JWT_SECRET!)) as User;
  const rows = await db.getUserRows(token_user.id);
  const lastReward: Date = rows[0].last_daily_reward;
  // lastReward.setDate(lastReward.getDate() - 1);
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

  const diffDays = Math.round(Math.abs((today.getTime() - lastReward.getTime()) / oneDay));
  if (diffDays > 0) {
    await new Promise(resolve => setTimeout(resolve, 1000));
    const points = diffDays >= 7 ? WEEKLY_BONUS_POINTS : DAILY_BONUS_POINTS;
    const profile = await db.addScore(token_user.id, points, true);
    const preferences = await db.getPreferences(profile.id);
    publish.userUpdate(client)(profile, preferences);
    publish.userMessage(client, `Welcome back! You got ${points}✪!`);
  }
};
