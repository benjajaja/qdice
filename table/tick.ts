import * as R from 'ramda';
import * as pmx from 'pmx';
import { getTable, save } from './get';
import { Table, Player, CommandResult } from '../types';
import { processComandResult } from '../table';
import { havePassed } from '../timestamp';
const probe = pmx.probe();

import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  ROLL_SECONDS,
} from '../constants';
import * as publish from './publish';
import nextTurn from './turn';
import startGame from './start';
import { rollResult } from './attack';
import logger from '../logger';

let globalTablesUpdate = null;

const updateCounter = probe.counter({
  name : 'Global mqtt updates'
});

const intervalIds: {[tableTag: string]: any} = {};
export const start = (tableTag: string) => {
  if (intervalIds[tableTag]) {
    throw new Error('already ticking');
  }
  intervalIds[tableTag] = setInterval(() => {
    tick(tableTag);
  }, 100);
};

export const stop = (tableTag: string) => {
  if (intervalIds[tableTag] === null) {
    throw new Error('cannot stop, not ticking');
  }
  clearInterval(intervalIds[tableTag]);
  delete intervalIds[tableTag];
};

const tick = async (tableTag: string) => {
  const table = await getTable(tableTag);
  let result: CommandResult | void = undefined;
  if (table.status === STATUS_PLAYING) {
    if (table.attack) {
      if (havePassed(ROLL_SECONDS, table.attack.start)) {
        result = rollResult(table);
      }
      // never process anything else during attack

    } else if (table.players[table.turnIndex].out) {
      result = nextTurn('TickTurnOut', table);

    } else if (havePassed(TURN_SECONDS, table.turnStart)) {
      result = nextTurn('TickTurnOver', table, !table.turnActivity);

    } else if (table.players.every(R.prop('out'))) {
      result = nextTurn('TickTurnAllOut', table);

    }

  } else if (table.status === STATUS_PAUSED) {
    if (table.players.length >= 2
        && table.gameStart !== 0
        && havePassed(0, table.gameStart)) {
      result = startGame(table);
    }
  }

  if (result === undefined) {
    result = cleanWatchers(table);
  }

  await processComandResult(table, result);
};

const cleanWatchers = (table: Table): CommandResult | undefined => {

  const [ stillWatching, stoppedWatching ] = table.watching.reduce(([yes, no], watcher) => {
    if (!havePassed(30, watcher.lastBeat)) {
      return [R.append(watcher, yes), no];
    } else {
      return [yes, R.append(watcher, no)];
    }
  }, [[], []]);

  if (stoppedWatching.length > 0) {
    stoppedWatching.forEach(user => publish.exit(table, user.name));
    logger.debug('stopped', stoppedWatching.map(R.prop('name')));
    logger.debug('still', stillWatching.map(R.prop('name')));
    return {
      type: 'CleanWatchers',
      watchers: stillWatching,
    };
  }
  return undefined;
};

