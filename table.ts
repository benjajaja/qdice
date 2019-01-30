import { promisify } from 'util';
import * as R from 'ramda';
import * as mqtt from 'mqtt';
import * as jwt from 'jsonwebtoken';

import { UserId, Table, CommandResult, Elimination, IllegalMoveError } from './types';
import * as db from './db';
import * as publish from './table/publish';
import * as tick from './table/tick';
import { getTable } from './table/get';
import { findTable, hasTurn, positionScore, tablePoints } from './helpers';
import logger from './logger';

import {
  heartbeat,
  enter,
  exit,
  join,
  leave,
  attack,
  endTurn,
  sitOut,
  sitIn,
  chat,
} from './table/commands';
import { save } from './table/get';

const verifyJwt = promisify(jwt.verify);

export const start = async (tableTag: string, client: mqtt.MqttClient) => {

  publish.tableStatus(await getTable(tableTag));

  client.subscribe(`tables/${tableTag}/server`);


  const onMessage = async (topic, message) => {
    if (topic !== `tables/${tableTag}/server`) {
      return;
    }

    const parsedMessage = parseMessage(message.toString());
    if (!parsedMessage) {
      return;
    }

    const { type, clientId, token, payload } = parsedMessage;
    try {
      const user = await (token
        ? verifyJwt(token, process.env.JWT_SECRET)
        : null
      );
      const table = await getTable(tableTag);

      const result = command(user, clientId, table, type, payload);
      await processComandResult(table, result);

    } catch (e) {
      publish.clientError(clientId, e);
      if ((e instanceof IllegalMoveError)) {
        logger.error(e, 'illegal move caught gracefully');
      } else {
        throw e;
      }
    }
  };

  client.on('message', onMessage);

  tick.start(tableTag);
  return () => {
    client.off('message', onMessage);
    tick.stop(tableTag);
  };
};

const parseMessage = (message: string): { type: string, clientId: string, token: string, payload: any | undefined } | null => {
  try {
    const { type, client: clientId, token, payload } = JSON.parse(message.toString());
    return { type, clientId, token, payload };
  } catch (e) {
    logger.error(e, 'Could not parse message');
    return null;
  }
};

const command = (user, clientId, table: Table, type, payload): CommandResult | void => {
  switch (type) {
    case 'Enter':
      return enter(user, table, clientId);
    case 'Exit':
      return exit(user, table, clientId);
    case 'Join':
      return join(user, table, clientId);
    case 'Leave':
      return leave(user, table, clientId);
    case 'Attack':
      return attack(user, table, clientId, payload);
    case 'EndTurn':
      return endTurn(user, table, clientId);
    case 'SitOut':
      return sitOut(user, table, clientId);
    case 'SitIn':
      return sitIn(user, table, clientId);
    case 'Chat':
      return chat(user, table, clientId, payload);
    //case 'Flag':
      //return flag(user, table, clientId);
    case 'Heartbeat':
      return heartbeat(user, table, clientId);
    default:
      throw new Error(`unknown command "${type}"`);
  }
};

export const processComandResult = async (table: Table, result: CommandResult | void) => {
  if (result) {
    const { type, table: props, lands, players, watchers, eliminations } = result;
    if (type !== 'Heartbeat') {
      logger.debug(`Command ${type} modified ${Object.keys(props || {})}, lands:${(lands || []).length}, players:${(players || []).length}, watchers:${(watchers || []).length}, eliminations:${(eliminations || []).length}`);
    }
    const newTable = await save(table, props, players, lands, watchers);
    if (eliminations) {
      await processEliminations(newTable, eliminations);
    }

    if (type !== 'Heartbeat') {
      publish.tableStatus(newTable);
    }
  }
};

const processEliminations = async (table: Table, eliminations: ReadonlyArray<Elimination>): Promise<void> => {
  return Promise.all(eliminations.map(async (elimination) => {
    const { player, position, reason, source } = elimination;

    const score = player.score + positionScore(tablePoints(table))(table.playerStartCount)(position);

    publish.elimination(table, player, position, score, {
      type: reason,
      ...source,
    });

    logger.debug('ELIMINATION-------------');
    logger.debug(position, player.name);
    try {
      const user = await db.addScore(player.id, score);
      publish.userUpdate(player.clientId)(user);
    } catch (e) {
      // send a message to this specific player
      publish.clientError(player.clientId, new Error(`You earned ${score} points, but I failed to add them to your profile.`));
      throw e;
    }
  })).then(() => undefined);
};
