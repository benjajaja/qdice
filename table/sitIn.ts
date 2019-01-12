import * as R from 'ramda';
import * as publish from './publish';
import nextTurn from './turn';
import { hasTurn } from '../helpers';
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
} from '../constants';

const sitIn = (user, table, clientId) => {
  if (table.status !== STATUS_PLAYING) {
    return publish.clientError(clientId, new Error('not playing'));
  }
  const player = table.players.filter(p => p.id === user.id).pop();
  if (!player) {
    return publish.clientError(clientId, new Error('not playing'));
  } else {
    const allOut = table.players.every(R.prop('out'));
    player.out = false;
    player.outTurns = 0;
    if (allOut) {
      nextTurn(table);
    }
  }

  publish.tableStatus(table);
};
export default sitIn;

