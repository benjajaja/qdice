import * as R from 'ramda';
import { Table, Player } from '../types';
import { save } from './get';
const publish = require('./publish');
import startGame from './start';
const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} = require('../constants');

const makePlayer = (user, clientId, playerCount): Player => ({
  id: user.id,
  clientId,
  name: user.name,
  picture: user.picture || '',
  color: playerCount + 1,
  reserveDice: 0,
  out: false,
  outTurns: 0,
  points: user.points,
  level: user.level,
  position: 0,
  score: 0,
  flag: null,
});
  
const join = async (user, table: Table, clientId) => {
  if (table.status === STATUS_PLAYING) {
    return publish.clientError(clientId, new Error('already playing'));
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (existing) {
    return publish.clientError(clientId, new Error('already joined'));
  }

  const players = table.players.concat([makePlayer(user, clientId, table.players.length)]);
  const status = table.status === STATUS_FINISHED
    ? STATUS_PAUSED
    : table.status;
  const lands = table.status === STATUS_FINISHED
    ? table.lands.map(land => Object.assign({}, land, {
        points: 1,
        color: -1,
      }))
    : table.lands;
  const turnCount = table.status === STATUS_FINISHED ? 1 : table.turnCount;

  //table.players = table.players.map((player, index) => Object.assign(player, { color: index + 1}));

  let gameStart = table.gameStart;
  let newTable = await save(table, { status, turnCount }, players, lands);
  if (table.players.length === table.playerSlots) {
    newTable = startGame(newTable);
  } else {
    if (newTable.players.length >= 2 &&
      newTable.players.length >= newTable.startSlots) {
      if (newTable.gameStart === 0) {
        publish.event({
          type: 'countdown',
          table: newTable.name,
          players: newTable.players.map(R.prop('name')),
        });
      }
      gameStart = Math.floor(Date.now() / 1000) + GAME_START_COUNTDOWN;
    }
  }
  newTable = await save(newTable, { gameStart });
  publish.tableStatus(newTable);
  publish.event({
    type: 'join',
    table: newTable.name,
    player: R.last(newTable.players),
    playerCount: newTable.players.length,
  });
};
export default join;

