import {Table} from '../types';
import {serializeTable, serializePlayer} from './serialize';
import * as jwt from 'jsonwebtoken';

let client;
export const setMqtt = client_ => {
  client = client_;
};

export const tableStatus = (table: Table, clientId?) => {
  client.publish(
    clientId ? `clients/${clientId}` : `tables/${table.tag}/clients`,
    JSON.stringify({
      type: 'update',
      payload: serializeTable(table),
      table: clientId ? table.name : undefined,
    }),
    undefined,
    err => {
      if (err) {
        console.log(err, 'tables/' + table.name + '/clients update', table);
      }
    },
  );
};

export const enter = (table: Table, name) => {
  client.publish(
    'tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'enter',
      payload: name,
    }),
    undefined,
    err => {
      if (err) {
        console.log(err, 'tables/' + table.name + '/clients enter', name);
      }
    },
  );
};

export const exit = (table, name) => {
  client.publish(
    'tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'exit',
      payload: name,
    }),
    undefined,
    err => {
      if (err) {
        console.log(err, 'tables/' + table.name + '/clients exit', name);
      }
    },
  );
};

export const roll = (table, roll) => {
  client.publish(
    'tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'roll',
      payload: roll,
    }),
    undefined,
    err => {
      if (err) {
        console.log(err, 'tables/' + table.name + '/clients roll', roll);
      }
    },
  );
};

export const move = (table, move) => {
  client.publish(
    'tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'move',
      payload: move,
    }),
    undefined,
    err => {
      if (err) {
        console.log(err, 'tables/' + table.name + '/clients move', table);
      }
    },
  );
};

export const elimination = (table, player, position, score, reason) => {
  client.publish(
    'tables/' + table.name + '/clients',
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
    err => {
      if (err) {
        console.log(
          err,
          'tables/' + table.name + '/clients elimination',
          table,
        );
      }

      event({
        type: 'elimination',
        table: table.name,
        player,
        position,
        score,
        reason,
      });
    },
  );
};

export const tables = globalTablesUpdate => {
  client.publish(
    'clients',
    JSON.stringify({
      type: 'tables',
      payload: globalTablesUpdate,
    }),
    undefined,
    err => {
      if (err) {
        console.log(err, 'clients tables');
      }
    },
  );
};

export const event = event => {
  client.publish('events', JSON.stringify(event), undefined, err => {
    if (err) {
      console.error('pub telegram error', err);
    }
  });
};

export const clientError = (clientId, error) => {
  console.error('client error', clientId, error);
  client.publish(
    `clients/${clientId}`,
    JSON.stringify({
      type: 'error',
      payload: error.toString(),
    }),
    undefined,
    err => {
      if (err) {
        console.error('pub clientError error', err);
      }
    },
  );
  if (!(error instanceof Error)) {
    console.trace('client error must be Error', error);
  }
};

export const chat = (table, user, message) => {
  client.publish(
    'tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'chat',
      payload: {user, message},
    }),
    undefined,
    err => {
      if (err) {
        console.log(err, 'tables/' + table.name + '/clients chat', table);
      }
    },
  );
};

export const userUpdate = clientId => profile => {
  const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET);
  client.publish(
    `clients/${clientId}`,
    JSON.stringify({
      type: 'user',
      payload: [profile, token],
    }),
    undefined,
    err => {
      if (err) {
        console.log(err, 'tables/?/clients update', clientId);
      }
    },
  );
};
