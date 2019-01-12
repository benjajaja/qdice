import * as R from 'ramda';
import { Client } from 'pg';
import { UserId, Network, Table } from './types';

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
  console.log('created user', user);
  if (network !== NETWORK_PASSWORD) {
    /*const { rows: [ auth ] } =*/
    await client.query('INSERT INTO authorizations (user_id,network,network_id,profile) VALUES ($1, $2, $3, $4) RETURNING *', [user.id, network, network_id, profileJson]);
  }
  return await getUser(user.id);
};

export const updateUser = async (id: UserId, name: string) => {
  console.log('update', id, name);
  const res = await client.query('UPDATE users SET name = $1 WHERE id = $2', [name, id]);
  return await getUser(id);
};


export const addScore = async (id: UserId, score: number) => {
  console.log('addScore', id, score);
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

