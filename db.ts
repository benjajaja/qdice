import * as R from "ramda";
import { native } from "pg";
import * as camelize from "camelize";
import * as decamelize from "decamelize";

import logger from "./logger";
import {
  UserId,
  Network,
  Table,
  Player,
  User,
  Emoji,
  Color,
  Watcher,
  PushNotificationEvents,
} from "./types";
import { date } from "./timestamp";
import * as sleep from "sleep-promise";
import * as config from "./tables.config"; // for e2e only
import AsyncLock = require("async-lock");

const pool = new native!.Pool({
  host: process.env.PGHOST,
  port: parseInt(process.env.PGPORT!, 10),
});

export const connect = async function db() {
  return await pool.connect();
};

export const retry = async function retry() {
  try {
    return await connect();
  } catch (e) {
    logger.error("pg connection error", e);
    await sleep(1000);
    return await retry();
  }
};

export const clearGames = async (lock: AsyncLock): Promise<void> => {
  lock.acquire([config.tables.map(table => table.name)], async done => {
    await pool.query(`DELETE FROM tables`);
    for (const table of config.tables) {
      const newTable = await require("./table/get").getTable(table.name);
      require("./table/publish").tableStatus(newTable);
    }
    logger.debug("E2E cleared all tables");
    done();
  });
};

export const NETWORK_GOOGLE: Network = "google";
export const NETWORK_PASSWORD: Network = "password";
export const NETWORK_TELEGRAM: Network = "telegram";
export const NETWORK_REDDIT: Network = "reddit";

export const getUser = async (id: UserId): Promise<User> => {
  const rows = await getUserRows(id);
  return userProfile(rows);
};

export const getUserRows = async (id: UserId) => {
  const user = await pool.query({
    name: "user-rows",
    text: `
SELECT a.*, authorizations.*, (SELECT COUNT(*) + 1 FROM users b WHERE b.points > a.points) AS rank
FROM users a
LEFT JOIN authorizations ON authorizations.user_id = a.id
WHERE a.id = $1
`,
    values: [id],
  });
  return user.rows;
};

export const getUserFromAuthorization = async (
  network: Network,
  id: UserId
) => {
  try {
    const res = await pool.query({
      name: "authorizations",
      text:
        "SELECT * FROM authorizations WHERE network = $1 AND network_id = $2",
      values: [network, id],
    });
    if (res.rows.length === 0) {
      return undefined;
    }
    return await getUser(res.rows[0].user_id);
  } catch (e) {
    console.error("user dont exist", e.toString());
    return undefined;
  }
};

export const getPreferences = async (id: UserId) => {
  const res = await pool.query({
    name: "preferences",
    text: `SELECT users.preferences, push_subscribed_events."event" AS "event"
    FROM users
    LEFT JOIN push_subscribed_events
    ON push_subscribed_events.user_id = users.id
    WHERE users.id = $1`,
    values: [id],
  });
  const preferences = res.rows[0]?.preferences ?? {};
  return {
    pushSubscribed: res.rows.filter(row => row.event).map(row => row.event),
    ...preferences,
  };
};

export const createUser = async (
  network: Network,
  network_id: string | null,
  name: String,
  email: string | null,
  picture: string | null,
  profileJson: any | null
) => {
  const {
    rows: [user],
  } = await pool.query(
    "INSERT INTO users (name,email,picture,registration_time,points) VALUES ($1, $2, $3, current_timestamp, 100) RETURNING *",
    [name, email, picture]
  );
  logger.info("created user", user.name);
  if (network !== NETWORK_PASSWORD) {
    /*const { rows: [ auth ] } =*/
    await pool.query(
      "INSERT INTO authorizations (user_id,network,network_id,profile) VALUES ($1, $2, $3, $4) RETURNING *",
      [user.id, network, network_id, profileJson]
    );
  }
  return await getUser(user.id);
};

export const addNetwork = async (
  userId: UserId,
  network: Network,
  network_id: string | null,
  profileJson: any | null
) => {
  await pool.query(
    "INSERT INTO authorizations (user_id,network,network_id,profile) VALUES ($1, $2, $3, $4) RETURNING *",
    [userId, network, network_id, profileJson]
  );
  return await getUser(userId);
};

export const updateUser = async (
  id: UserId,
  fields: {
    name: string | null;
    email: string | null;
    picture: string | null;
  }
) => {
  const columns = Object.keys(fields).filter(k => fields[k] !== null);
  if (columns.length === 0) {
    throw new Error("user update needs some fields");
  }
  const values = [id].concat(columns.map(k => fields[k]));

  const text = `
UPDATE users
SET (${columns.join(", ")})
  = (${columns.map((_, i) => `$${i + 2}`).join(", ")})
WHERE id = $1
RETURNING *`;
  await pool.query(text, values);
  return await getUser(id);
};

// export const updateUserPreferences = async (
// id: UserId,
// preferences: Preferences
// ) => {
// const res = await client.query(
// "UPDATE users SET preferences = $2 WHERE id = $1",
// [id, preferences]
// );
// return await getUser(id);
// };

export const addPushSubscription = async (
  id: UserId,
  subscription: any,
  add: boolean
) => {
  if (add) {
    await pool.query(
      "INSERT INTO push_subscriptions (user_id, subscription) VALUES ($1, $2)",
      [id, subscription]
    );
  } else {
    await pool.query(
      `DELETE FROM push_subscriptions WHERE user_id = $1 AND subscription = $2`,
      [id, subscription]
    );
  }
  return await getUser(id);
};

export const addPushEvent = async (
  id: UserId,
  event: PushNotificationEvents,
  add: boolean
) => {
  if (add) {
    await pool.query(
      `INSERT INTO push_subscribed_events (user_id, "event") VALUES ($1, $2)`,
      [id, event]
    );
  } else {
    await pool.query(
      `DELETE FROM push_subscribed_events WHERE user_id = $1 AND "event" = $2`,
      [id, event]
    );
  }
  return await getUser(id);
};

export const registerVote = async (user: User, source: "topwebgames") => {
  await pool.query(
    `
      UPDATE users SET voted = $1 WHERE id = $2`,
    [JSON.stringify(user.voted.concat([source])), user.id]
  );
  return await getUser(user.id);
};

export const deleteUser = async (id: UserId) => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query("DELETE FROM authorizations WHERE user_id = $1", [id]);
    await client.query("DELETE FROM push_subscriptions WHERE user_id = $1", [
      id,
    ]);
    await client.query(
      "DELETE FROM push_subscribed_events WHERE user_id = $1",
      [id]
    );
    await client.query("DELETE FROM users WHERE id = $1", [id]);
    await client.query("COMMIT");
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
};

export const addScore = async (id: UserId, score: number) => {
  logger.debug("addScore", id, score);
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    const res = await client.query(
      `
      UPDATE users
      SET points = GREATEST(points + $1, 0),
          level_points = GREATEST(level_points + $1, 0)
      WHERE id = $2
      RETURNING level, level_points`,
      [score, id]
    );
    const { level, level_points } = res.rows[0];
    logger.debug("setLevel", level, level_points);
    if (level_points > 0) {
      const nextLevelPoints = Math.ceil(Math.pow(level + 1 + 10, 3) * 0.1);
      logger.debug("nextLevelPoints", nextLevelPoints);
      if (level_points > nextLevelPoints) {
        const newLevelPoints = Math.max(0, level_points - nextLevelPoints);
        const newLevel = level + 1;
        logger.debug("new level", newLevel, newLevelPoints);
        await client.query(
          `
          UPDATE users
          SET level = $1,
              level_points = $2
          WHERE id = $3`,
          [newLevel, newLevelPoints, id]
        );
      }
    }
    await client.query("COMMIT");
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
  return await getUser(id);
};

export const leaderBoardTop = async (limit = 100, page = 1) => {
  const result = await pool.query({
    name: "leaderboard",
    text: `
SELECT id, name, picture, points, level,
  ROW_NUMBER () OVER (ORDER BY points DESC) AS rank,
  level_points, awards
FROM users
ORDER BY points DESC
LIMIT $1 OFFSET $2`,
    values: [limit, limit * Math.max(0, page - 1)],
  });
  return result.rows.map(row => ({
    ...row,
    id: row.id.toString(),
    points: parseInt(row.points, 10),
    rank: parseInt(row.rank, 10),
    level: Math.max(1, row.level),
    levelPoints: Math.max(1, row.level_points),
    awards: row.awards,
    picture: row.picture || "assets/empty_profile_picture.svg",
  }));
};

export const userProfile = (rows: any[]): User => {
  const {
    id,
    name,
    email,
    picture,
    level,
    level_points,
    points,
    rank,
    preferences,
    voted,
    awards,
  } = rows[0];
  return {
    id: id.toString(),
    name,
    email,
    picture: picture || "assets/empty_profile_picture.svg",
    level,
    levelPoints: level_points,
    claimed: rows.some(
      row => row.network !== NETWORK_PASSWORD || row.network_id !== null
    ),
    points: parseInt(points, 10),
    rank: parseInt(rank, 10),
    networks: rows.map(row => row.network || "password"),
    voted,
    awards,
  };
};

export const getTable = async (tag: string) => {
  const result = await pool.query({
    name: "table",
    text: `
SELECT *
FROM tables
WHERE tag = $1
LIMIT 1`,
    values: [tag],
  });
  const row = camelize(result.rows.pop());
  if (!row) {
    return null;
  }
  return {
    ...row,
    gameStart: row.gameStart ? row.gameStart.getTime() : 0,
    turnStart: row.turnStart ? row.turnStart.getTime() : 0,
  };
};

export const createTable = async (table: Table) => {
  const result = await pool.query(
    `
INSERT INTO tables
(tag, name, map_name, stack_size, player_slots, start_slots, points, players, lands, watching, player_start_count, status, turn_index, turn_activity, turn_count, round_count, game_start, turn_start, params)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19)
RETURNING *`,
    [
      table.tag,
      table.name,
      table.mapName,
      table.stackSize,
      table.playerSlots,
      table.startSlots,
      table.points,
      JSON.stringify(table.players),
      JSON.stringify(table.lands),
      JSON.stringify(table.watching),
      table.playerStartCount,
      table.status,
      table.turnIndex,
      table.turnActivity,
      table.turnCount,
      table.roundCount,
      date(table.gameStart),
      date(table.turnStart),
      JSON.stringify(table.params),
    ]
  );
  const row = result.rows.pop();
  return camelize(row);
};

export const saveTable = async (
  tag: string,
  props: Partial<Table> = {},
  players?: ReadonlyArray<Player>,
  lands?: ReadonlyArray<{ emoji: Emoji; color: Color; points: number }>,
  watching?: ReadonlyArray<Watcher>
) => {
  const propColumns = Object.keys(props);
  const propValues = propColumns.map(column => {
    if (column === "gameStart" || column === "turnStart") {
      return date(props[column]!);
    }
    return props[column];
  });
  const values = [tag as any]
    .concat(propValues)
    .concat(players ? [JSON.stringify(players)] : [])
    .concat(lands ? [JSON.stringify(lands)] : [])
    .concat(watching ? [JSON.stringify(watching)] : []);

  const extra = (players ? ["players"] : [])
    .concat(lands ? ["lands"] : [])
    .concat(watching ? ["watching"] : []);
  const columns = propColumns.concat(extra);
  const decamelizedColumns = columns.map(column => decamelize(column));
  const name = "W" + decamelizedColumns.join("-");
  const text = `
UPDATE tables
SET (${decamelizedColumns.join(", ")})
  = (${columns.map((_, i) => `$${i + 2}`).join(", ")})
WHERE tag = $1
RETURNING *`;
  if (values.some(value => value === undefined)) {
    logger.error(
      "undefined db",
      columns,
      values.map(v => `${v}`)
    );
    throw new Error("got undefined db value, use null");
  }
  const result =
    name.length < 64
      ? await pool.query({ name, text, values })
      : await pool.query(text, values);
  return camelize(result.rows.pop());
};

export const getTablesStatus = async (): Promise<any> => {
  const result = await pool.query({
    name: "tables-status",
    text: `
SELECT tag, name, map_name, stack_size, status, player_slots, start_slots, points, players, watching, params
FROM tables
LIMIT 100`,
  });
  return result.rows.map(camelize);
};

export const deleteTable = async (tag: string): Promise<any> =>
  await pool.query("DELETE FROM tables WHERE tag = $1", [tag]);

export const getPushSubscriptions = async (event: string) => {
  const res = await pool.query({
    name: "push-subscriptions",
    text: `SELECT users.id, users.name, push_subscribed_events."event" AS "event", push_subscriptions.subscription
    FROM users
    LEFT JOIN push_subscribed_events
    ON push_subscribed_events.user_id = users.id
    LEFT JOIN push_subscriptions
    ON push_subscriptions.user_id = users.id
    WHERE push_subscribed_events."event" = $1`,
    values: [event],
  });
  return res.rows;
};
