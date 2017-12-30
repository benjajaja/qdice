const promisify = require('util').promisify;
const R = require('ramda');

const mqtt = require('mqtt');
const jwt = require('jsonwebtoken');

const maps = require('./maps');
const publish = require('./table/publish');
const startGame = require('./table/start');
const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} = require('./constants');
const { findTable, hasTurn } = require('./helpers');

const tableConfig = require('./tables.config').tables.filter(
  config => config.tag === process.env.TABLE
).pop();
const tableTag = tableConfig.tag;

if (R.isEmpty(tableTag)) {
  throw new Error('table proc did not get env TABLENAME, exitting');
}
console.log(`Table proc for ${tableTag} starting up...`);


const Table = config => ({
  name: config.tag,
  tag: config.tag,
  players: [],
  playerSlots: config.playerSlots,
  startSlots: config.startSlots,
  status: STATUS_FINISHED,
  gameStart: 0,
  turnIndex: -1,
  turnStarted: 0,
  turnActivity: false,
  lands: [],
  stackSize: config.stackSize,
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
  process.send('ready');
});

process.on('SIGINT', () => {
  client.end(() => {
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
    const { type, client: clientId, token, payload } = JSON.parse(message);

    try {
      const user = await (token
        ? verifyJwt(token, process.env.JWT_SECRET)
        : async () => null
      );
      await command(user, clientId, table, type, payload);
    } catch (e) {
      publish.clientError(clientId, e.toString());
    }
  } catch (e) {
    console.error('error parsing message', e);
  }
});

const command = async (user, clientId, table, type, payload) => {
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
    default:
      throw new Error(`unknown command "${type}"`);
  }
};


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
