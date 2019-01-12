import { promisify } from 'util';
import * as R from 'ramda';
import * as mqtt from 'mqtt';
import * as jwt from 'jsonwebtoken';

import { UserId, Table } from './types';
import * as db from './db';
import * as publish from './table/publish';
import * as tick from './table/tick';
import { getTable } from './table/get';
import { findTable, hasTurn } from './helpers';

import heartbeat from './table/heartbeat';
import enter from './table/enter';
import exit from './table/exit';
import join from './table/join';
import leave from './table/leave';
import attack from './table/attack';
import endTurn from './table/endTurn';
import sitOut from './table/sitOut';
import sitIn from './table/sitIn';
import chat from './table/chat';
import flag from './table/flag';

const verifyJwt = promisify(jwt.verify);

export const start = async (tableTag: string, client: mqtt.MqttClient) => {

  publish.tableStatus(await getTable(tableTag));

  client.subscribe(`tables/${tableTag}/server`);


  const onMessage = async (topic, message) => {
    if (topic !== `tables/${tableTag}/server`) {
      return;
    }
    try {
      const { type, client: clientId, token, payload } = JSON.parse(message.toString());

      try {
        const user = await (token
          ? verifyJwt(token, process.env.JWT_SECRET)
          : null
        );
        const table = await getTable(tableTag);
        await command(user, clientId, table, type, payload);
      } catch (e) {
        publish.clientError(clientId, e);
      }
    } catch (e) {
      console.error('error parsing message', e);
    }
  };
  client.on('message', onMessage);

  tick.start(tableTag);
  return () => {
    client.off('message', onMessage);
    tick.stop(tableTag);
  };
};

const command = async (user, clientId, table: Table, type, payload) => {
  heartbeat(user, table, clientId);
  switch (type) {
    case 'Enter':
      return await enter(user, table, clientId);
    case 'Exit':
      return await exit(user, table, clientId);
    case 'Join':
      return await join(user, table, clientId);
    case 'Leave':
      return await leave(user, table, clientId);
    case 'Attack':
      return await attack(user, table, clientId, payload);
    case 'EndTurn':
      return await endTurn(user, table, clientId);
    case 'SitOut':
      return await sitOut(user, table, clientId);
    case 'SitIn':
      return await sitIn(user, table, clientId);
    case 'Chat':
      return await chat(user, table, clientId, payload);
    case 'Flag':
      return await flag(user, table, clientId);
    case 'Heartbeat':
      return;
    default:
      throw new Error(`unknown command "${type}"`);
  }
};

