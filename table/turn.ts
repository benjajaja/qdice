import * as R from 'ramda';
import * as maps from '../maps';
import endGame from './endGame';
import { serializePlayer } from './serialize';
import { rand } from '../rand';
import logger from '../logger';
import { UserId, Table, Land, User, Player, Watcher, CommandResult, CommandType, IllegalMoveError } from '../types';
import { updateLand } from '../helpers';

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
import { now } from '../timestamp';

const turn = (type: CommandType, table: Table, sitPlayerOut = false): CommandResult => {
  const inPlayers = sitPlayerOut
    ? R.adjust(player => ({ ...player, out: true }), table.turnIndex, table.players)
    : table.players;

  const currentPlayer = inPlayers[table.turnIndex];
  const [lands, players] = currentPlayer
    ? giveDice(table, table.lands.slice() as Land[], inPlayers as Player[])(currentPlayer) // not just removed
    : [table.lands, table.players];

  const nextIndex = (i => i + 1 < players.length ? i + 1 : 0)(table.turnIndex);
  const props = {
    turnIndex: nextIndex,
    turnStart: now(),
    turnActivity: false,
    turnCount: table.turnCount + 1,
    roundCount: table.turnIndex === 0
      ? table.roundCount + 1
      : table.roundCount,
  };

  const newPlayer = players[props.turnIndex];

  if (!newPlayer.out) {
    // normal turn over
    return { type, table: props, lands, players };
  }

  if (newPlayer.outTurns > OUT_TURN_COUNT_ELIMINATION) {
    const eliminations = [{ player: newPlayer, position: players.length, reason: ELIMINATION_REASON_OUT, source: {
      turns: newPlayer.outTurns,
    }}];
    const [players_, lands_] = removePlayer(players, lands)(newPlayer);
    if (players_.length === players.length) {
      throw new Error(`could not remove player ${newPlayer.id}`);
    }
    logger.debug('sat out:', newPlayer, players_.length);
    props.turnIndex = (i => i + 1 < players_.length ? i + 1 : 0)(props.turnIndex);

    const result = { type, table: props, lands: lands_, players: players_, eliminations };

    if (players_.length === 1) {
      // okthxbye
      return endGame(table, result);
    } else {
      return result;
    }
  }

  return {
    type,
    table: props,
    lands: lands,
    players: players.map(player => {
      if (player === newPlayer) {
        return { ...player, outTurns: player.outTurns + 1 };
      }
      return player;
    }),
  };
};

const giveDice = (table: Table, lands: ReadonlyArray<Land>, players: ReadonlyArray<Player>) => (player: Player): [ReadonlyArray<Land>, ReadonlyArray<Player>] => {

  const playerLands = lands.filter(land => land.color === player.color);
  const newDies =
    maps.countConnectedLands({ lands, adjacency: table.adjacency })(player.color)
    + player.reserveDice;

  let reserveDice = 0;

  R.range(0, newDies).forEach(i => {
    const targets = playerLands.filter(land => land.points < table.stackSize);
    if (targets.length === 0) {
      reserveDice += 1;
    } else {
      let index = rand(0, targets.length - 1);
      const target = targets[index];
      lands = updateLand(lands, target, { points: target.points + 1 });
    }
  });
  // TODO
  return [lands, players.map(p => p === player
      ? { ...player, reserveDice }
      : p)];
};

const removePlayer = (players: ReadonlyArray<Player>, lands: ReadonlyArray<Land>) => (player: Player): [ReadonlyArray<Player>, ReadonlyArray<Land>] => {
  return [
    players.filter(R.complement(R.equals(player))),
    lands.map(R.when(R.propEq('color', player.color), land => Object.assign(land, { color: COLOR_NEUTRAL })))
  ];
};

export default turn;
