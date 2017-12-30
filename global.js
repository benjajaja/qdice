var R = require('ramda');
const mqtt = require('mqtt');

const {
  TURN_SECONDS,
  GAME_START_COUNTDOWN,
  MAX_NAME_LENGTH,
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
} = require('./constants');
const publish = require('./table/publish');
const { findTable } = require('./helpers');

const tablesConfig = require('./tables.config');

const tables = tablesConfig.tables.map(config => ({
  tag: config.tag,
  name: config.tag,
  playerSlots: config.playerSlots,
  stackSize: config.stackSize,
  points: config.points,
  status: STATUS_PAUSED,
  landCount: 0,
  players: [],
}));

module.exports = function(req, res, next) {
  res.send(200, {
    settings: {
      turnSeconds: TURN_SECONDS,
      gameCountdownSeconds: GAME_START_COUNTDOWN,
      maxNameLength: MAX_NAME_LENGTH,
    },
    tables: getTablesStatus(tables),
  });
  next();
};

const getTablesStatus = module.exports.getTablesStatus = (tables) =>
  tables.map(table =>
    Object.assign(R.pick([
      'name',
      'tag',
      'stackSize',
      'status',
      'playerSlots',
      'landCount',
    ])(table), {
      playerCount: table.players.length,
    })
  );

console.log('connecting to mqtt: ' + process.env.MQTT_URL);
var client = mqtt.connect(process.env.MQTT_URL, {
  username: process.env.MQTT_USERNAME,
  password: process.env.MQTT_PASSWORD,
});
client.on('connect', () => {
  client.subscribe('events');
});
publish.setMqtt(client);

client.on('message', (topic, message) => {
  if (topic === 'events') {
    const event = JSON.parse(message);
    switch (event.type) {

      case 'join': {
        const table = findTable(tables)(event.table);
        if (!table) {
          return;
        }
        table.players.push(event.player);
        publish.tables(getTablesStatus(tables));

        return;
      }

      case 'leave': {
        const table = findTable(tables)(event.table);
        if (!table) {
          return;
        }
        table.players = table.players.filter(p => p.id !== event.player.id);
        console.log('left', table);
        publish.tables(getTablesStatus(tables));
        return;
      }

      case 'elimination': {
        const { table, player, position, score } = event;
        table.players = table.players.filter(p => p.id === event.player.id);
        publish.tables(getTablesStatus(tables));
        return;
      }
    }
  }
});


