const { serializeTable, serializePlayer } = require('./serialize');
const jwt = require('jsonwebtoken');

let client;
module.exports.setMqtt = client_ => {
  client = client_;
};

module.exports.tableStatus = (table, clientId) => {
  client.publish(clientId
    ? `clients/${clientId}`
    : `tables/${table.name}/clients`,
    JSON.stringify({
      type: 'update',
      payload: serializeTable(table),
    }),
    undefined,
    (err) => {
			if (err) {
				console.log(err, 'tables/' + table.name + '/clients update', table);
			}
		}
  );
};

module.exports.enter = (table, name) => {
  client.publish('tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'enter',
      payload: name,
    }),
    undefined,
    (err) => {
			if (err) {
				console.log(err, 'tables/' + table.name + '/clients enter', name);
			}
		}
  );
};


module.exports.exit = (table, name) => {
  client.publish('tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'exit',
      payload: name,
    }),
    undefined,
    (err) => {
			if (err) {
				console.log(err, 'tables/' + table.name + '/clients exit', name);
			}
		}
  );
};

module.exports.roll = (table, roll) => {
  client.publish('tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'roll',
      payload: roll,
    }),
    undefined,
    (err) => {
			if (err) {
				console.log(err, 'tables/' + table.name + '/clients roll', roll);
			}
		}
  );
};

module.exports.move = (table, move) => {
  client.publish('tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'move',
      payload: move
    }),
    undefined,
    (err) => {
			if (err) {
				console.log(err, 'tables/' + table.name + '/clients move', table);
			}
		}
  );
};

module.exports.elimination = (table, player, position, score, reason) => {
  client.publish('tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'elimination',
      payload: {
        player: serializePlayer(table)(player),
        position,
        score,
        reason,
      },
    }),
    undefined,
    (err) => {
			if (err) {
				console.log(err, 'tables/' + table.name + '/clients elimination', table);
			}

      module.exports.event({
        type: 'elimination',
        table: table.name,
        player,
        position,
        score,
        reason,
      });
		}
  );
};

module.exports.tables = globalTablesUpdate => {
  client.publish('clients',
    JSON.stringify({
      type: 'tables',
      payload: globalTablesUpdate,
    }),
    undefined,
    (err) => {
      if (err) {
        console.log(err, 'clients tables');
      }
    }
  );
};

module.exports.event = event => {
  client.publish('events',
    JSON.stringify(event),
    undefined,
    err => {
      if (err) {
        console.error('pub telegram error', err);
      }
    }
  );
};

module.exports.clientError = (clientId, error) => {
  console.error('client error', clientId, error);
  client.publish(`clients/${clientId}`, JSON.stringify({
    type: 'error',
    payload: error.toString(),
  }), undefined,
    err => {
      if (err) {
        console.error('pub clientError error', err);
      }
    }
  );
};

module.exports.chat = (table, user, message) => {
  client.publish('tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'chat',
      payload: { user, message },
    }),
    undefined,
    (err) => {
			if (err) {
				console.log(err, 'tables/' + table.name + '/clients chat', table);
			}
		}
  );
};

module.exports.userUpdate = clientId => profile => {
  const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET);
  client.publish(`clients/${clientId}`,
    JSON.stringify({
      type: 'user',
      payload: [profile, token],
    }),
    undefined,
    (err) => {
			if (err) {
				console.log(err, 'tables/' + table.name + '/clients update', table);
			}
		}
  );
};

