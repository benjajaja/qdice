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
import { Table, Land, IllegalMoveError } from '../types';
import logger from '../logger';

const attack = async (user, table: Table, clientId, [emojiFrom, emojiTo]) => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError('attack while not STATUS_PLAYING', user, emojiFrom, emojiTo);
  }
  if (!hasTurn(table)(user)) {
    throw new IllegalMoveError('attack while not having turn', user, emojiFrom, emojiTo);
  }

  const find = findLand(table.lands);
  const fromLand: Land = find(emojiFrom);
  const toLand = find(emojiTo);
  if (!fromLand || !toLand) {
    throw new IllegalMoveError('some land not found in attack', user, emojiFrom, emojiTo, fromLand, toLand);
  }
  if (fromLand.color === COLOR_NEUTRAL) {
    throw new IllegalMoveError('attack from neutral', user, emojiFrom, emojiTo, fromLand, toLand);
  }
  if (fromLand.points === 1) {
    throw new IllegalMoveError('attack from single-die land', user, emojiFrom, emojiTo, fromLand, toLand);
  }
  if (fromLand.color === toLand.color) {
    throw new IllegalMoveError('attack same color', user, emojiFrom, emojiTo, fromLand, toLand);
  }
  if (!isBorder(table.adjacency, emojiFrom, emojiTo)) {
    throw new IllegalMoveError('attack not border', user, emojiFrom, emojiTo, fromLand, toLand);
  }

  const newTable = await save(table, { turnStart: Math.floor(Date.now() / 1000), turnActivity: true });
  publish.move(newTable, {
    from: emojiFrom,
    to: emojiTo,
  });

  setTimeout(() => {
    rollResult(newTable.tag, fromLand, toLand, clientId);
  }, 1000);
};
export default attack;

const rollResult = async (tableTag: string, fromLand: Land, toLand: Land, clientId: string) => {
    try {
      let emojiFrom = fromLand.emoji;
      let emojiTo = toLand.emoji;
      let table = await getTable(tableTag);
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
            return await endGame(table);
          }
          table = update(table, { turnIndex: table.players.indexOf(turnPlayer) });
        }
      }

      lands = updateLand(lands, fromLand, { points: 1 })

      table = await save(table, { turnStart: Math.floor(Date.now() / 1000) }, undefined, lands);
      publish.tableStatus(table);
    } catch (e) {
      publish.clientError(clientId, new Error('roll failed'));
      throw e;
    }
  }

const updateLand = (lands: ReadonlyArray<Land>, target: Land, props: Partial<Land>): ReadonlyArray<Land> => {
  return lands.map(land => {
    if (land.emoji !== target.emoji) {
      return land;
    }
    logger.debug('updateLand', land.emoji, props)
    return { ...land, ...props };
  });
};

