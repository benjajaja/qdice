const R = require('ramda');
let singleton;
let client;

module.exports.db = db;

async function db() {
  if (singleton) {
    return singleton;
  }

  const { Client } = require('pg');
  const client_ = client = new Client();

  await client_.connect();

  return singleton = new Db(client_);
}

class Db {
  constructor(client) {
    this.client = client;
  }
}

module.exports.NETWORK_GOOGLE = 'google';
module.exports.NETWORK_PASSWORD = 'password';
module.exports.NETWORK_TELEGRAM = 'telegram';
const networks = [
  module.exports.NETWORK_GOOGLE,
  module.exports.NETWORK_PASSWORD,
  module.exports.NETWORK_TELEGRAM,
];

//module.exports.getUser = async id => {
  //const user = await client.query(`SELECT * FROM users WHERE id = $1 `, [id]);
  //return user.rows[0];
//};

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
    return await module.exports.getUserRows(res.rows[0].user_id);
  } catch (e) {
    console.error('user dont exist', e.toString());
    return undefined;
  }
};

module.exports.createUser = async (network, network_id, name, email, picture, profileJson) => {
  const { rows : [ user ] } = await client.query('INSERT INTO users (name,email,picture) VALUES ($1, $2, $3) RETURNING *', [name, email, picture]);
  console.log('created user', user);
  const { rows: [ auth ] } = await client.query('INSERT INTO authorizations (user_id,network,network_id,profile) VALUES ($1, $2, $3, $4) RETURNING *', [user.id, network, network_id, profileJson]);
  return await module.exports.getUserRows(user.id);
};

module.exports.updateUser = async (id, name) => {
  const res = await client.query('UPDATE users SET name = $1', [name]);
  return await module.exports.getUserRows(id);
};

