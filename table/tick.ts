import * as R from 'ramda';
import * as pmx from 'pmx';
import { getTable, save } from './get';
import { Table, Player } from '../types';
const probe = pmx.probe();

const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
} = require('../constants');
import nextTurn from './turn';
import * as publish from './publish';
import startGame from './start';

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
  }, 500);
};
export const stop = (tableTag: string) => {
  if (intervalIds[tableTag] === null) {
    throw new Error('cannot stop, not ticking');
  }
  clearInterval(intervalIds[tableTag]);
  delete intervalIds[tableTag];
};

const tick = async (tableTag: string) => {
  const oldTable = await getTable(tableTag);
  let table = oldTable;
  if (table.status === STATUS_PLAYING) {
    if (table.turnStarted < Date.now() / 1000 - (TURN_SECONDS + 1)) {
      table = await nextTurn(table);
      publish.tableStatus(table);
    } else if (table.players.every(R.prop('out'))) {
      table = await nextTurn(table);
      publish.tableStatus(table);
    }

  } else if (table.status === STATUS_PAUSED) {
    if (table.players.length >= 2
        && table.gameStart !== 0
        && table.gameStart < Date.now() / 1000) {
      table = startGame(table);
      publish.tableStatus(table);
    }
  }

  const [ stillWatching, stoppedWatching ] = table.watching.reduce(([yes, no], watcher) => {
    if (watcher.lastBeat > Date.now() - 30 * 1000) {
      return [R.append(watcher, yes), no];
    } else {
      return [yes, R.append(watcher, no)];
    }
  }, [[], []]);

  if (stoppedWatching.length > 0) {
    publish.event({
      type: 'watching',
      table: table.name,
      watching: stillWatching.map(R.prop('name')),
    });
  }

  if (table !== oldTable) {
    await save(table, { watching: stillWatching });
  }

  //const newUpdate = require('../global').getTablesStatus(tables);
  //if (!R.equals(newUpdate)(globalTablesUpdate)) {
    //globalTablesUpdate = newUpdate;
    //publish.tables(globalTablesUpdate);
    //probe.metric({
      //name: 'Players',
      //value: R.always(R.sum(R.map(R.prop('playerCount'))(newUpdate))),
    //});
    //updateCounter.inc();
  //}
};

