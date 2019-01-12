import * as R from 'ramda';
import * as publish from './publish';
const elimination = require('./elimination');
const nextTurn = require('./turn');
const { hasTurn, groupedPlayerPositions } = require('../helpers');
const { serializePlayer } = require('./serialize');
const endGame = require('./endGame');
const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
  ELIMINATION_REASON_SURRENDER,
} = require('../constants');

const flag = (user, table, clientId) => {
  if (table.status !== STATUS_PLAYING) {
    return publish.clientError(clientId, new Error('not playing'));
  }
  if (table.roundCount < table.noFlagRounds) {
    return publish.clientError(clientId, new Error('cannot flag yet'));
  }
  const player = table.players.filter(p => p.id === user.id).pop();
  if (!player) {
    return publish.clientError(clientId, new Error('not playing'));
  } else {
    const position = groupedPlayerPositions(table)(player);
    if (position === 1) {
      return publish.clientError(clientId, new Error('cannot flag for 1st'));
    }
    player.flag = position;

    if (hasTurn(table)(player)) {
      if (table.players.length === position) {
        elimination(table, player, ELIMINATION_REASON_SURRENDER, {
          flag: player.flag,
        });
        table.players = table.players.filter(R.complement(R.propEq('id', player.id)));
        table.lands = table.lands.map(land => {
          if (land.color === player.color) {
            land.color = COLOR_NEUTRAL;
          }
          return land;
        });
        if (table.players.length === 1) {
          endGame(table);
        } else {
          nextTurn(table);
        }
      }
    }
  }
  publish.tableStatus(table);
};
export default flag;

