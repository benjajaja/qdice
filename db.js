const R = require('ramda');

let client;

module.exports.connect = db;

async function db() {
  if (client) {
    return client;
  }

  const { Client } = require('pg');
  client = new Client();

  await client.connect();

  return client;
}

module.exports.NETWORK_GOOGLE = 'google';
module.exports.NETWORK_PASSWORD = 'password';
module.exports.NETWORK_TELEGRAM = 'telegram';
const networks = [
  module.exports.NETWORK_GOOGLE,
  module.exports.NETWORK_PASSWORD,
  module.exports.NETWORK_TELEGRAM,
];


const userProfile = rows => Object.assign({},
  R.pick(['id', 'name', 'email', 'picture', 'network', 'level'], rows[0]),
  {
    id: rows[0].id.toString(),
    picture: rows[0].picture || 'assets/empty_profile_picture.svg',
    claimed: rows.some(row => row.network !== db.NETWORK_PASSWORD
      || row.network_id !== null),
    points: parseInt(rows[0].points, 10),
  }
);

module.exports.getUser = async id => {
  const rows = await module.exports.getUserRows(id);
  return userProfile(rows);
};


module.exports.getUserRows = async id => {
  const user = await client.query(`
SELECT *
FROM users
LEFT JOIN authorizations ON authorizations.user_id = users.id
WHERE id = $1
`, [id]);
  return user.rows;
};

module.exports.getUserFromAuthorization = async (network, id) => {
  try {
    const res = await client.query('SELECT * FROM authorizations WHERE network = $1 AND network_id = $2', [network, id]);
    if (res.rows.length === 0) {
      return undefined;
    }
    return await module.exports.getUser(res.rows[0].user_id);
  } catch (e) {
    console.error('user dont exist', e.toString());
    return undefined;
  }
};

module.exports.createUser = async (network, network_id, name, email, picture, profileJson) => {
  const { rows : [ user ] } = await client.query('INSERT INTO users (name,email,picture,registration_time) VALUES ($1, $2, $3, current_timestamp) RETURNING *', [name, email, picture]);
  console.log('created user', user);
  if (network !== module.exports.NETWORK_PASSWORD) {
    /*const { rows: [ auth ] } =*/
    await client.query('INSERT INTO authorizations (user_id,network,network_id,profile) VALUES ($1, $2, $3, $4) RETURNING *', [user.id, network, network_id, profileJson]);
  }
  return await module.exports.getUser(user.id);
};

module.exports.updateUser = async (id, name) => {
  console.log('update', id, name);
  const res = await client.query('UPDATE users SET name = $1 WHERE id = $2', [name, id]);
  return await module.exports.getUser(id);
};


module.exports.addScore = async (id, score) => {
  console.log('addScore', id, score);
  const res = await client.query(`
UPDATE users
SET points = GREATEST(points + $1, 0)
WHERE id = $2`, [score, id]);
  return await module.exports.getUser(id);
};

