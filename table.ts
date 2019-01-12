const promisify = require('util').promisify;
import * as R from 'ramda';

import * as mqtt from 'mqtt';
import * as jwt from 'jsonwebtoken';
import * as db from './db';
import * as maps from './maps.js';
import * as publish from './table/publish';
import * as startGame from './table/start';
import * as tick from './table/tick';
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} from './constants';
import { findTable, hasTurn } from './helpers';


const Table = config => ({
  name: config.tag,
  tag: config.tag,
  players: [],
  playerSlots: config.playerSlots,
  startSlots: config.startSlots,
  points: config.points,
  status: STATUS_FINISHED,
  gameStart: 0,
  turnIndex: -1,
  turnStarted: 0,
  turnActivity: false,
  lands: [],
  stackSize: config.stackSize,
  playerStartCount: 0,
  turnCount: 1,
  roundCount: 1,
  noFlagRounds: config.noFlagRounds,
  watching: [],
});
const loadLands = table => {
  const [ lands, adjacency, name ] = maps.loadMap(table.tag);
  return Object.assign({}, table, {
    name,
    lands: lands.map(land => Object.assign({}, land, {
      color: COLOR_NEUTRAL,
      points: 1,
    })),
    adjacency
  });
};

module.exports = function(tableTag) {
  if (R.isEmpty(tableTag)) {
    throw new Error('table proc did not get env TABLENAME, exitting');
  }
  console.log(`Table proc for ${tableTag} starting up...`);

  const tableConfig = require('./tables.config').tables.filter(
    config => config.tag === tableTag
  ).pop();



  const table = loadLands(Table(tableConfig));


  console.log('connecting to mqtt: ' + process.env.MQTT_URL);
  var client = mqtt.connect(process.env.MQTT_URL, {
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
  });
   
  client.on('error', err => console.error(err));


  client.on('connect', function () {
    console.log('mqtt connected');
    publish.tableStatus(table);
    if (process.send) {
      process.send('ready');
    }
  });

  db.connect().then(() => console.log('table connected to DB'));

  process.on('SIGINT', () => {
    (client.end as any)(() => {
      console.log('table stopped gracefully');
      process.exit(0);
    });
  });

  publish.setMqtt(client);

  client.subscribe(`tables/${table.tag}/server`);

  const verifyJwt = promisify(jwt.verify);

  client.on('message', async (topic, message) => {
    if (topic !== `tables/${table.tag}/server`) {
      return console.error('bad topic: ' + topic);
    }
    try {
      const { type, client: clientId, token, payload } = JSON.parse(message.toString());

      try {
        const user = await (token
          ? verifyJwt(token, process.env.JWT_SECRET)
          : null
        );
        await command(user, clientId, table, type, payload);
      } catch (e) {
        publish.clientError(clientId, e);
      }
    } catch (e) {
      console.error('error parsing message', e);
    }
  });

  const command = async (user, clientId, table, type, payload) => {
    require('./table/heartbeat')(user, table, clientId);
    switch (type) {
      case 'Enter':
        return await require('./table/enter')(user, table, clientId);
      case 'Exit':
        return await require('./table/exit')(user, table, clientId);
      case 'Join':
        return await require('./table/join')(user, table, clientId);
      case 'Leave':
        return await require('./table/leave')(user, table, clientId);
      case 'Attack':
        return await require('./table/attack')(user, table, clientId, payload);
      case 'EndTurn':
        return await require('./table/endTurn')(user, table, clientId);
      case 'SitOut':
        return await require('./table/sitOut')(user, table, clientId);
      case 'SitIn':
        return await require('./table/sitIn')(user, table, clientId);
      case 'Chat':
        return await require('./table/chat')(user, table, clientId, payload);
      case 'Flag':
        return await require('./table/flag')(user, table, clientId, payload);
      case 'Heartbeat':
        return;
      default:
        throw new Error(`unknown command "${type}"`);
    }
  };

  tick.start(table);

  //tables.forEach(table =>
    //table.players = R.range(0,7).map(i =>
      //Object.assign(Player({
        //id: `fake_${i}`,
        //name: `Pikachu${i} Random name`,
        //picture: 'http://i.imgur.com/WgP9bNm.jpg',
      //}), {
        //color: i + 1
      //})
    //)
  //);
  //module.exports.getTables = function() {
    //return tables;
  //};
};
