import * as R from "ramda";
import { Pool } from "pg";
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
  CommandResult,
  Command,
  PlayerStats,
} from "./types";
import { date, now, ts } from "./timestamp";
import * as sleep from "sleep-promise";
import * as config from "./tables.config"; // for e2e only
import AsyncLock = require("async-lock");
import { EMPTY_PROFILE_PICTURE } from "./constants";

const pool = new Pool({
  host: process.env.PGHOST,
  port: parseInt(process.env.PGPORT!, 10),
  database: process.env.PGDATABASE,
  user: process.env.PGUSER,
  password: process.env.POSTGRES_PASSWORD,
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

export const getUser = async (
  id: UserId,
  ip?: string | undefined
): Promise<User> => {
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
  if (network !== NETWORK_PASSWORD) {
    // Don't let other networks eat up emails, this would confuse users if their email has been taken
    // by themself. A user can manually set his email to a federated login, though.
    email = null;
  }
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

const setPassword = async (userId: UserId, password: string): Promise<User> => {
  const client = await pool.connect();
  try {
    await client.query("BEGIN");
    await client.query(
      "DELETE FROM authorizations WHERE user_id = $1 AND network = $2",
      [userId, NETWORK_PASSWORD]
    );
    await client.query(
      "INSERT INTO authorizations (user_id,network,network_id,profile) VALUES ($1, $2, $3, $4) RETURNING *",
      [userId, NETWORK_PASSWORD, password, {}]
    );
    await client.query("COMMIT");
    return await getUser(userId);
  } catch (e) {
    await client.query("ROLLBACK");
    throw e;
  } finally {
    client.release();
  }
};

export const getPassword = async (userId: UserId): Promise<string> => {
  const rows = await pool.query(
    "SELECT network_id FROM authorizations WHERE user_id = $1 AND network = $2",
    [userId, NETWORK_PASSWORD]
  );
  return rows.rows[0].network_id;
};

export const getUserId = async (email: string): Promise<UserId> => {
  const rows = await pool.query("SELECT id FROM users WHERE email = $1", [
    email,
  ]);
  return rows.rows[0].id;
};

export const updateUser = async (
  id: UserId,
  fields: {
    name: string | null;
    email: string | null;
    picture: string | null;
    password: string | null;
  }
) => {
  const columns = Object.keys(fields).filter(
    k => k !== "password" && fields[k] !== null
  );
  if (columns.length === 0 && !fields.password) {
    throw new Error("user update needs some fields");
  }

  if (columns.length > 0) {
    const values = [id].concat(columns.map(k => fields[k]));

    const text = `
  UPDATE users
  SET (${columns.join(", ")})
    = (${columns.map((_, i) => `$${i + 2}`).join(", ")})
  WHERE id = $1
  RETURNING *`;
    await pool.query(text, values);
  }

  if (fields.password) {
    await setPassword(id, fields.password);
  }
  return await getUser(id);
};

export const updateUserStats = async (id: UserId, stats: PlayerStats) => {
  const res = await pool.query("UPDATE users SET stats = $2 WHERE id = $1", [
    id,
    stats,
  ]);
  return await getUser(id);
};

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
    picture: row.picture || EMPTY_PROFILE_PICTURE,
  }));
};

export const userProfile = (
  rows: {
    id: number;
    email: string;
    name: string;
    picture: string;
    level: number;
    level_points: number;
    points: string;
    rank: string;
    preferences: any;
    voted: any[];
    awards: any[];
    network: Network;
    network_id: string | null;
  }[],
  ip?: string | undefined
): User => {
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
    networks: rows.map(row => row.network).filter(R.identity),
    voted,
    awards,
    ip,
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
    retired: row.retired ?? [],
  };
};

export const createTable = async (table: Table) => {
  const result = await pool.query(
    `
INSERT INTO tables
(tag, name, map_name, stack_size, player_slots, start_slots, points, players, lands, watching, player_start_count, status, turn_index, turn_activity, turn_count, round_count, game_start, turn_start, params, retired)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20)
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
      JSON.stringify(table.retired),
    ]
  );
  const row = camelize(result.rows.pop());
  return {
    ...row,
    gameStart: row.gameStart ? row.gameStart.getTime() : 0,
    turnStart: row.turnStart ? row.turnStart.getTime() : 0,
    retired: row.retired ?? [],
  };
};

export const saveTable = async (
  tag: string,
  props: Partial<Table> = {},
  players?: ReadonlyArray<Player>,
  lands?: ReadonlyArray<{ emoji: Emoji; color: Color; points: number }>,
  watching?: ReadonlyArray<Watcher>,
  retired?: ReadonlyArray<Player>
): Promise<Table | null> => {
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
    .concat(watching ? [JSON.stringify(watching)] : [])
    .concat(retired ? [JSON.stringify(retired)] : []);

  const extra = (players ? ["players"] : [])
    .concat(lands ? ["lands"] : [])
    .concat(watching ? ["watching"] : [])
    .concat(retired ? ["retired"] : []);
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

  const row = camelize(result.rows.pop()) ?? {};
  if (!row) {
    logger.warn("UPDATE did not RETURN table");
    return null;
  }
  return {
    ...row,
    gameStart: row.gameStart ? row.gameStart.getTime() : 0,
    turnStart: row.turnStart ? row.turnStart.getTime() : 0,
    retired: row.retired ?? [],
  };
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

export const removePushSubscription = async (
  id: string,
  subscription: string
) => {
  const res = await pool.query({
    name: "push-subscriptions-remove",
    text: `DELETE FROM push_subscriptions WHERE user_id = $1 AND subscription::text = $2`,
    values: [id, subscription],
  });
  return res;
};

export const addGame = async (table: Table): Promise<{ id: number }> => {
  const {
    rows: [game],
  } = await pool.query(
    `INSERT INTO games (tag, name, map_name, stack_size, player_slots, start_slots, points, game_start, params, players, lands)
    VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
    RETURNING *`,
    [
      table.tag,
      table.name,
      table.mapName,
      table.stackSize,
      table.playerSlots,
      table.startSlots,
      table.points,
      date(table.gameStart),
      JSON.stringify(table.params),
      JSON.stringify(table.players),
      JSON.stringify(table.lands),
    ]
  );
  logger.info(
    "db created game",
    game.id,
    game.tag,
    game.gameStart,
    game.players.map(p => p.name)
  );
  return game;
};

export const addGameEvent = async (gameId: number, command: Command) => {
  const slimCommand: any = {
    ...command,
  };
  if (slimCommand.player) {
    slimCommand.player = {
      id: slimCommand.player.id,
      name: slimCommand.player.name,
    };
  }
  if (slimCommand.user) {
    slimCommand.user = {
      id: slimCommand.user.id,
      name: slimCommand.user.name,
    };
  }
  if (slimCommand.winner) {
    slimCommand.winner = {
      id: slimCommand.winner.id,
      name: slimCommand.winner.name,
    };
  }

  delete slimCommand.clientId;
  const {
    rows: [event],
  } = await pool.query({
    name: "game-event",
    text: `INSERT INTO game_events (game_id, command, params, result)
    VALUES ($1, $2, $3, $4)
    RETURNING *`,
    values: [gameId, command.type, JSON.stringify(slimCommand), "{}"],
  });
  // logger.info("created game event", event.id, event.game_id, event.command);
  return event;
};

const validTableTags: string[] = config.tables.map(table => table.tag);
export const games = async (table?: string) => {
  if (table && validTableTags.indexOf(table) === -1) {
    throw new Error(`bad table tag: ${table}`);
  }
  const { rows: games } = await (table
    ? pool.query({
        name: `games-${table}`,
        text: `SELECT * FROM games WHERE tag = $1 ORDER BY game_start DESC LIMIT 200`,
        values: [table],
      })
    : pool.query({
        name: "games-all",
        text: `SELECT * FROM games ORDER BY game_start DESC LIMIT 200`,
        values: [],
      }));
  return games.map(camelize);
};

export const game = async (id: string) => {
  const { rows: games } = await pool.query({
    name: "games-id",
    text: `SELECT * FROM games WHERE games.id = $1`,
    values: [id],
  });

  const { rows: gameEvents } = await pool.query({
    name: "games-id-events",
    text: `SELECT * FROM game_events WHERE game_events.game_id = $1 ORDER BY id ASC`,
    values: [id],
  });
  const game = { ...games[0], events: gameEvents ?? [] };
  return camelize(game);
};

export const chat = async (table: string) => {
  const { rows: gameEvents } = await pool.query({
    name: "games-events-chat",
    text: `SELECT params->'user' as user, params->>'message' as message, game_id
      FROM game_events
      WHERE command = 'Chat' AND game_id IN (SELECT id FROM games WHERE tag = $1 ORDER BY id DESC LIMIT 1000)
      ORDER BY game_events.id DESC
      LIMIT 1000`,
    values: [table],
  });
  return gameEvents;
};

export const chatByGame = async (gameId: number) => {
  const { rows: gameEvents } = await pool.query({
    name: "games-events-chat-game",
    text: `SELECT params->'user' as user, params->>'message' as message
      FROM game_events
      WHERE command = 'Chat' AND game_id = $1
      ORDER BY game_events.id DESC
      LIMIT 100`,
    values: [gameId],
  });
  return gameEvents;
};

export const isAvailable = async (email: string) => {
  const { rows } = await pool.query({
    text: `SELECT email FROM users WHERE email = $1`,
    values: [email],
  });
  logger.debug(rows, rows.length);
  return rows.length === 0;
};

export const userStats = async (id: string) => {
  const { rows: rows } = await pool.query({
    name: "user-stats-stats",
    text: `SELECT stats FROM users WHERE id = $1`,
    values: [id],
  });
  return rows[0].stats;
};

export const getUserStats = async (id: string) => {
  const { rows: games } = await pool.query({
    name: "user-stats-games",
    text: `SELECT id, tag, game_start FROM games, LATERAL (SELECT json_array_elements(games.players) c) lat WHERE lat.c->>'id' = $1 ORDER BY game_start DESC LIMIT 10`,
    values: [id],
  });
  const { rows: gamesWonCount } = await pool.query({
    name: "user-stats-games_won",
    text: `SELECT COUNT(*) as games_won FROM game_events WHERE command = 'EndGame' AND params->'winner'->>'id' = $1`,
    values: [id],
  });
  const { rows: gamesPlayedCount } = await pool.query({
    name: "user-stats-games_played",
    text: `SELECT COUNT(*) as games_played FROM games, LATERAL (SELECT json_array_elements(games.players) c) lat WHERE lat.c->>'id' = $1`,
    values: [id],
  });
  return {
    games: games.map(camelize),
    gamesWon: parseInt(gamesWonCount[0].games_won, 10),
    gamesPlayed: parseInt(gamesPlayedCount[0].games_played, 10),
    stats: await userStats(id),
  };
};

export const comments = async (kind: string, kindId: string) => {
  const result = await pool.query({
    name: "comments",
    text: `SELECT comments.*,
      users.id as author_id, users.name as author_name, users.picture as author_picture
    FROM comments
    LEFT JOIN users ON users.id = comments.author
    WHERE (comments.kind = $1 AND comments.kind_id = $2)
      OR (comments.kind = 'comments' AND comments.kind_id::int IN
        (SELECT id FROM comments WHERE comments.kind = $1 AND comments.kind_id = $2)
      )
    ORDER BY timestamp
    DESC LIMIT 100`,
    values: [kind, kindId],
  });

  const list = result.rows.map(camelize).map((row: any) => ({
    id: row.id,
    kind: [row.kind, row.kindId],
    body: row.body,
    author: {
      id: row.authorId,
      name: row.authorName,
      picture: row.authorPicture || EMPTY_PROFILE_PICTURE,
    },
    timestamp: ts(date(row.timestamp)),
    replies: [],
  }));

  const topComments = list.filter(comment => comment.kind[0] === kind);
  return list
    .filter(comment => comment.kind[0] === "comments")
    .reduce((list, reply) => {
      return list.map(top => {
        if (top.id.toString() === reply.kind[1]) {
          return {
            ...top,
            replies: R.sortBy(R.prop("timestamp"), [...top.replies, reply]),
          };
        }
        return top;
      });
    }, topComments);
};

export const postComment = async (
  user: User,
  kind: string,
  kindId: string,
  body: string
) => {
  const result = await pool.query({
    name: "post-comment",
    text: `INSERT INTO comments (author, kind, kind_id, body, timestamp)
    VALUES ($1, $2, $3, $4, $5)
    RETURNING *`,
    values: [user.id, kind, kindId, body, date(now())],
  });
  const id = result.rows[0].id;
  const { rows } = await pool.query({
    name: "comment",
    text: `SELECT comments.*,
      users.id as author_id, users.name as author_name, users.picture as author_picture
    FROM comments
    LEFT JOIN users ON users.id = comments.author
    WHERE comments.id = $1
    ORDER BY timestamp
    DESC LIMIT 100`,
    values: [id],
  });
  return rows.map(camelize).map((row: any) => ({
    id: row.id,
    kind: [row.kind, row.kindId],
    body: row.body,
    author: {
      id: row.authorId,
      name: row.authorName,
      picture: row.authorPicture || EMPTY_PROFILE_PICTURE,
    },
    timestamp: ts(date(row.timestamp)),
    replies: [],
  }))[0];
};
