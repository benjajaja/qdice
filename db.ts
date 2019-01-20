import * as R from 'ramda';
import { Client } from 'pg';
import * as camelize from 'camelize';
import * as decamelize from 'decamelize';

import logger from './logger';
import { UserId, Network, Table, Player, Land, Emoji, Color, Watcher } from './types';
import { date } from './timestamp';

let client: Client;

export const connect = async function db() {
  if (client) {
    return client;
  }

  client = new Client();

  await client.connect();

  return client;
};

export const NETWORK_GOOGLE: Network = 'google';
export const NETWORK_PASSWORD: Network = 'password';
export const NETWORK_TELEGRAM: Network = 'telegram';


export const getUser = async (id: UserId) => {
  const rows = await getUserRows(id);
  return userProfile(rows);
};


export const getUserRows = async (id: UserId) => {
  const user = await client.query(`
SELECT *
FROM users
LEFT JOIN authorizations ON authorizations.user_id = users.id
WHERE id = $1
`, [id]);
  return user.rows;
};

export const getUserFromAuthorization = async (network: Network, id: UserId) => {
  try {
    const res = await client.query('SELECT * FROM authorizations WHERE network = $1 AND network_id = $2', [network, id]);
    if (res.rows.length === 0) {
      return undefined;
    }
    return await getUser(res.rows[0].user_id);
  } catch (e) {
    console.error('user dont exist', e.toString());
    return undefined;
  }
};

export const createUser = async (network: Network, network_id: string | null, name: String, email: string | null, picture: string | null, profileJson: any | null) => {
  const { rows : [ user ] } = await client.query('INSERT INTO users (name,email,picture,registration_time) VALUES ($1, $2, $3, current_timestamp) RETURNING *', [name, email, picture]);
  logger.info('created user', user);
  if (network !== NETWORK_PASSWORD) {
    /*const { rows: [ auth ] } =*/
    await client.query('INSERT INTO authorizations (user_id,network,network_id,profile) VALUES ($1, $2, $3, $4) RETURNING *', [user.id, network, network_id, profileJson]);
  }
  return await getUser(user.id);
};

export const updateUser = async (id: UserId, name: string) => {
  logger.info('update user', id, name);
  const res = await client.query('UPDATE users SET name = $1 WHERE id = $2', [name, id]);
  return await getUser(id);
};


export const addScore = async (id: UserId, score: number) => {
  logger.debug('addScore', id, score);
  const res = await client.query(`
UPDATE users
SET points = GREATEST(points + $1, 0)
WHERE id = $2`, [score, id]);
  return await getUser(id);
};

export const leaderBoardTop = async (page = 1) => {
  const limit = 10;
  const result = await client.query(`
SELECT id, name, picture, points, level, ROW_NUMBER () OVER (ORDER BY points DESC) AS rank
FROM users
ORDER BY points DESC
LIMIT $1 OFFSET $2`,
    [limit, limit * Math.max(0, page - 1)]
  );
  return result.rows.map(row => Object.assign(row, {
    id: row.id.toString(),
    points: parseInt(row.points, 10),
    rank: parseInt(row.rank, 10),
    picture: row.picture || '',
  }));
};

const userProfile = (rows: any[]) => Object.assign({},
  R.pick(['id', 'name', 'email', 'picture', 'network', 'level'], rows[0]),
  {
    id: rows[0].id.toString(),
    picture: rows[0].picture || 'assets/empty_profile_picture.svg',
    claimed: rows.some(row => row.network !== NETWORK_PASSWORD
      || row.network_id !== null),
    points: parseInt(rows[0].points, 10),
  }
);

export const getTable = async (tag: string) => {
  const result = await client.query(`
SELECT *
FROM tables
WHERE tag = $1
LIMIT 1`,
    [tag]
  );
  const row = camelize(result.rows.pop());
  if (!row) {
    return null;
  }
  return Object.assign({}, row, {
    gameStart: row.gameStart ? row.gameStart.getTime() : 0,
    turnStart: row.turnStart ? row.turnStart.getTime() : 0,
  });
};

export const createTable = async (table: Table) => {
  const result = await client.query(`
INSERT INTO tables
(tag, name, map_name, stack_size, player_slots, start_slots, points, players, lands, watching, player_start_count, status, turn_index, turn_activity, turn_count, round_count, game_start, turn_start)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18)
RETURNING *`,
    [table.tag,
      table.name,
      table.mapName,
      table.stackSize,
      table.playerSlots,
      table.startSlots,
      table.points,
      JSON.stringify(table.players),
      JSON.stringify(table.lands),
      JSON.stringify(table.watching),
      table.playerStartCount, table.status, table.turnIndex, table.turnActivity, table.turnCount, table.roundCount,
      date(table.gameStart),
      date(table.turnStart),
    ]
  );
  const row = result.rows.pop();
  return camelize(row);
};

export const saveTable = async (
  tag: string,
  props: Partial<Table> = {},
  players?: ReadonlyArray<Player>,
  lands?: ReadonlyArray<{ emoji: Emoji, color: Color, points: number }>,
  watching?: ReadonlyArray<Watcher>
) => {
  const propColumns = Object.keys(props);
  const propValues = propColumns.map(column => {
    if (column === 'gameStart' || column === 'turnStart') {
      return date(props[column]!);
    }
    return props[column];
  });
  const values = [tag as any].concat(propValues)
    .concat(players ? [JSON.stringify(players)] : [])
    .concat(lands ? [JSON.stringify(lands)] : [])
    .concat(watching ? [JSON.stringify(watching)] : []);

  const extra = (players ? ['players'] : [])
    .concat(lands ? ['lands'] : [])
    .concat(watching ? ['watching'] : []);
  const columns = propColumns.concat(extra);

  const query = `
UPDATE tables
SET (${columns.map(column => decamelize(column)).join(', ')})
  = (${columns.map((_, i) => `$${i + 2}`).join(', ')})
WHERE tag = $1
RETURNING *`;
  if (values.some(value => value === undefined)) {
    logger.error('undefined db', columns, values.map(v => `${v}`));
    throw new Error('got undefined db value, use null');
  }
  const result = await client.query(query, values);
  return camelize(result.rows.pop());
};

export const getTablesStatus = async (): Promise<any> => {
  const result = await client.query(`
SELECT tag, name, map_name, stack_size, status, player_slots, points, players, watching
FROM tables
LIMIT 100`
  );
  return result.rows.map(camelize);
};

