const probe = require('pmx').probe();
const { serializeTable } = require('./serialize');

const publishTableMeter = probe.meter({
  name: 'Table mqtt updates',
  samples: 1,
  timeFrame: 60,
});

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
  publishTableMeter.mark();
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

module.exports.elimination = (table, player, position, reason) => {
  const score = {
    1: 90,
    2: 60,
    3: 30,
    4: 10,
    5: 0,
    6: 0,
    7: 0,
  }[position] || 0;
  client.publish('tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'elimination',
      payload: {
        player,
        position,
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