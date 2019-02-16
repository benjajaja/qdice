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
import { findLand, hasTurn, tablePoints, updateLand } from '../helpers';
import * as publish from './publish';
import endGame from './endGame';
import { isBorder } from '../maps';
import { computePlayerDerived, PlayerDerived } from './serialize';
import { Table, Player, Land, CommandResult, Elimination, IllegalMoveError } from '../types';
import { now } from '../timestamp';
import logger from '../logger';


export const rollResult = (table: Table): CommandResult => {
  if (!table.attack || !table.attack.clientId) {
    throw new Error(`rollResult without attack.clientId: ${table.attack}`);
  }
  try {
    const find = findLand(table.lands);
    const fromLand: Land = find(table.attack.from);
    const toLand = find(table.attack.to);
    const [fromRoll, toRoll, isSuccess] = diceRoll(fromLand.points, toLand.points);
    publish.roll(table, {
      from: { emoji: table.attack.from, roll: fromRoll },
      to: { emoji: table.attack.to, roll: toRoll },
    });
    let lands = table.lands;
    let players = table.players;
    let eliminations: ReadonlyArray<Elimination> | undefined = undefined;
    let turnIndex: number | undefined = undefined;
    if (isSuccess) {
      const loser = R.find(R.propEq('color', toLand.color), table.players);
      lands = updateLand(table.lands, toLand, { points: fromLand.points - 1, color: fromLand.color });
      if (loser && R.filter(R.propEq('color', loser.color), lands).length === 0) {
        const turnPlayer = table.players[table.turnIndex];
        const remainingPlayers = table.players.filter(R.complement(R.equals(loser)))
        turnIndex = remainingPlayers.indexOf(turnPlayer);
        players = remainingPlayers.map(player => {
            if (player === turnPlayer) {
              return ({ ...player, score: player.score + tablePoints(table) / 2 });
            }
            return player;
          });
        const eliminatedPlayerInfo: Player & { derived: PlayerDerived } = Object.assign({}, turnPlayer, {
          derived: computePlayerDerived(table)(turnPlayer),
        });
        eliminations = [{
          player: loser,
          position: players.length + 1,
          reason: ELIMINATION_REASON_DIE,
          source: {
            player: eliminatedPlayerInfo,
            points: tablePoints(table) / 2,
          },
        }];
      }
    }

    lands = updateLand(lands, fromLand, { points: 1 })

    const props = Object.assign({ turnStart: now(), attack: null },
      turnIndex !== undefined
        ? { turnIndex }
      : {}
    );
    const result: CommandResult = {
      type: 'Roll',
      table: props,
      players,
      lands,
      eliminations,
    };

    if (players.length === 1) {
      return endGame(table, result);
    }
    return result;

  } catch (e) {
    publish.clientError(table.attack.clientId, new Error('Roll failed'));
    logger.error(e);
    throw e;
  }
}

