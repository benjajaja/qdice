import * as R from 'ramda';
import { rand, diceRoll } from '../rand';
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
  ELIMINATION_REASON_DIE,
  ELIMINATION_REASON_WIN,
} from '../constants';
import { findLand, hasTurn, tablePoints } from '../helpers';
import * as publish from './publish';
import endGame from './endGame';
import elimination from './elimination';
import { isBorder } from '../maps';
import { serializePlayer } from './serialize';
import { getTable, update, save } from './get';
import { Table, Land } from '../types';

const attack = async (user, table: Table, clientId, [emojiFrom, emojiTo]) => {
  if (table.status !== STATUS_PLAYING) {
    return publish.clientError(clientId, new Error('game not running'));
  }
  if (!hasTurn(table)(user)) {
    return publish.clientError(clientId, new Error('out of turn'));
  }
  const find = findLand(table.lands);
  const fromLand: Land = find(emojiFrom);
  const toLand = find(emojiTo);
  if (!fromLand || !toLand) {
    return publish.clientError(clientId, new Error('land not found'));
  }
  if (fromLand.color === COLOR_NEUTRAL) {
    return publish.clientError(clientId, new Error('illegal move (same color)'));
  }
  if (fromLand.points === 1) {
    return publish.clientError(clientId, new Error('illegal move (single dice)'));
  }
  if (fromLand.color === toLand.color) {
    return publish.clientError(clientId, new Error('illegal move (same color)'));
  }
  if (!isBorder(table.adjacency, emojiFrom, emojiTo)) {
    return publish.clientError(clientId, new Error('illegal move (not adjacent)'));
  }

  const newTable = await save(table, { turnStarted: Math.floor(Date.now() / 1000), turnActivity: true });
  publish.move(newTable, {
    from: emojiFrom,
    to: emojiTo,
  });

  setTimeout(async () => {
    try {
      let table = await getTable(newTable.tag);
      const [fromRoll, toRoll, isSuccess] = diceRoll(fromLand.points, toLand.points);
      publish.roll(table, {
        from: { emoji: emojiFrom, roll: fromRoll },
        to: { emoji: emojiTo, roll: toRoll },
      });
      let lands = table.lands;
      if (isSuccess) {
        const loser = R.find(R.propEq('color', toLand.color), table.players);
        lands = updateLand(table.lands, toLand, { points: fromLand.points - 1, color: fromLand.color });
        if (loser && R.filter(R.propEq('color', loser.color), table.lands).length === 0) {
          const turnPlayer = table.players[table.turnIndex];
          elimination(table, loser, ELIMINATION_REASON_DIE, {
            player: serializePlayer(table)(turnPlayer),
            points: tablePoints(table) / 2,
          });
          const players = table.players.filter(R.complement(R.equals(loser)))
            .map(player => {
              if (player === turnPlayer) {
                return ({ ...player, score: player.score + tablePoints(table) / 2 });
              }
              return player;
            });
          table = update(table, { }, players);
          if (table.players.length === 1) {
            table = await endGame(table);
          }
          table = update(table, { turnIndex: table.players.indexOf(turnPlayer) });
        }
      }

      lands = updateLand(lands, fromLand, { points: 1 })

      table = await save(table, { turnStarted: Math.floor(Date.now() / 1000) }, undefined, lands);
      publish.tableStatus(table);
    } catch (e) {
      console.error(e);
      return publish.clientError(clientId, new Error('roll failed'));
    }
  }, 1000);
};
export default attack;

const updateLand = (lands: ReadonlyArray<Land>, target: Land, props: Partial<Land>): ReadonlyArray<Land> => {
  return lands.map(land => {
    if (land !== target) {
      return land;
    }
    return { ...land, ...props };
  });
};

