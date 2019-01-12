import * as R from 'ramda';
import * as maps from '../maps';
import endGame from './endGame';
import elimination from './elimination';
import { serializePlayer } from './serialize';
import { rand } from '../rand';

import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  ELIMINATION_REASON_OUT,
  ELIMINATION_REASON_WIN,
  ELIMINATION_REASON_SURRENDER,
  OUT_TURN_COUNT_ELIMINATION,
} from '../constants';
import { Table, Player, Land } from '../types';
import { update, save } from './get';

const turn = async (table: Table): Promise<Table> => {
  let newTable = table;

  const currentPlayer = table.players[table.turnIndex];
  if (currentPlayer) { // not just removed
    newTable = giveDice(table)(currentPlayer);
  }

  const nextIndex = (i => i + 1 < table.players.length ? i + 1 : 0)(table.turnIndex);
  newTable = update(newTable, {
    turnIndex: nextIndex,
    turnStarted: Math.floor(Date.now() / 1000),
    turnActivity: false,
    turnCount: newTable.turnCount + 1,
    roundCount: newTable.turnIndex === 0
      ? newTable.roundCount + 1
      : newTable.roundCount,
  });

  const newPlayer = newTable.players[newTable.turnIndex];
  /*if (newPlayer.flag === table.players.length) {
    elimination(table, newPlayer, ELIMINATION_REASON_SURRENDER, {
      flag: newPlayer.flag,
    });
    table.players = table.players.filter(R.complement(R.equals(newPlayer)));
    table.lands = table.lands.map(land => {
      if (land.color === newPlayer.color) {
        land.color = COLOR_NEUTRAL;
      }
      return land;
    });
    if (table.players.length === 1) {
      table = endGame(table);
    } else {
      return module.exports(table);
    }

  } else*/
  if (newPlayer.out) {
    if (newPlayer.outTurns > OUT_TURN_COUNT_ELIMINATION) {
      elimination(newTable, newPlayer, ELIMINATION_REASON_OUT, {
        turns: newPlayer.outTurns,
      });
      newTable = removePlayer(newTable)(newPlayer);

      if (newTable.players.length === 1) {
        // okthxbye
        return await endGame(newTable);
      }
    } else {
      newTable = update(table, newTable, newTable.players.map(player => {
        if (player === newPlayer) {
          return { ...player, outTurns: player.outTurns + 1 };
        }
        return player;
      }));
    }
    if (!newTable.players.every(R.prop('out'))) {
      return turn(newTable);
    }
  }
  return await save(table, newTable);
};

const giveDice = (table: Table) => (player: Player): Table => {
  let out = !table.turnActivity && !player.out
    ? true
    : player.out;

  const playerLands = table.lands.filter(land => land.color === player.color);
  const newDies =
    maps.countConnectedLands(table)(player.color)
    + player.reserveDice;

  let reserveDice = 0;

  let lands = [...table.lands];
  R.range(0, newDies).forEach(i => {
    const targets = playerLands.filter(land => land.points < table.stackSize);
    if (targets.length === 0) {
      reserveDice += 1;
    } else {
      let index = rand(0, targets.length - 1);
      const target = targets[index];
      lands = [...lands.slice(0, index), { ...target, points: target.points + 1 }, ...lands.slice(index)];
    }
  });
  return update(
    table,
    {},
    table.players.map(p => p === player
      ? { ...player, out, reserveDice }
      : p), 
    lands);
};

const removePlayer = (table: Table) => (player: Player): Table => {
  return update(
    table,
    {},
    table.players.filter(R.complement(R.equals(player))),
    table.lands.map(R.when(R.propEq('color', player.color), land => Object.assign(land, { color: COLOR_NEUTRAL })))
  );
};

export default turn;
