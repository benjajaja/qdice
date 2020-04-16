import * as R from "ramda";
import {
  findLand,
  updateLand,
  removePlayerCascade,
  tablePoints,
} from "../helpers";
import * as publish from "./publish";
import {
  Table,
  Land,
  CommandResult,
  Elimination,
  Command,
  Player,
} from "../types";
import { now } from "../timestamp";
import logger from "../logger";
import { botsNotifyAttack } from "./bots";
import { playerWithDerived } from "./serialize";
import { ELIMINATION_REASON_DIE, TURN_SECONDS } from "../constants";
import { isBorder } from "../maps";
import { shuffle } from "../rand";

export const rollResult = (
  table: Table,
  fromRoll: number[],
  toRoll: number[]
): [CommandResult, Command | null] => {
  if (!table.attack) {
    throw new Error(`rollResult without attack: ${table.attack}`);
  }
  try {
    const find = findLand(table.lands);
    const fromLand: Land = find(table.attack.from);
    const toLand = find(table.attack.to);
    const isSuccess = R.sum(fromRoll) > R.sum(toRoll);

    let lands = table.lands;
    let newCapital: Land | null = null;
    let players = botsNotifyAttack(table);
    let eliminations: ReadonlyArray<Elimination> | undefined = undefined;
    let turnIndex: number | undefined = undefined;
    const attacker = players[table.turnIndex];
    if (isSuccess) {
      const loser: Player | undefined = R.find(
        R.propEq("color", toLand.color),
        players
      );
      lands = updateLand(table.lands, toLand, {
        points: fromLand.points - 1,
        color: fromLand.color,
        capital: false,
      });
      if (
        loser &&
        R.filter(R.propEq("color", loser.color), lands).length === 0
      ) {
        [players, lands, turnIndex, eliminations] = removePlayerCascade(
          players,
          lands,
          loser,
          table.turnIndex,
          {
            player: playerWithDerived(table, loser),
            position: players.length,
            reason: ELIMINATION_REASON_DIE,
            source: {
              player: playerWithDerived(table, attacker),
              points: tablePoints(table) / 2,
            },
          }
        );
        logger.debug(
          `Attack produced ${eliminations.length} eliminations: ${table.players.length} -> ${players.length}`
        );
        // update attacker score
        players = players.map(player => {
          if (player === attacker) {
            return { ...player, score: player.score + tablePoints(table) / 2 };
          }
          return player;
        });
      } else if (table.params.capitals && loser && toLand.capital) {
        newCapital = shuffle(lands.filter(R.propEq("color", loser.color)))[0];
        lands = updateLand(lands, newCapital, { capital: true });
        if (loser.reserveDice > 0) {
          logger.debug(
            `Giving ${loser.reserveDice} reserveDice from ${loser.name} to ${attacker.name}`
          );
          players = players.map(player => {
            if (player.id === loser.id) {
              return { ...player, reserveDice: 0 };
            } else if (player.id === attacker.id) {
              return {
                ...player,
                reserveDice: player.reserveDice + loser.reserveDice,
              };
            }
            return player;
          });
        }
      }
    }

    lands = updateLand(lands, fromLand, { points: 1 });

    const canAttack = (land: Land) => {
      return (
        land.points > 1 &&
        lands
          .filter(land => land.color !== attacker.color)
          .some(other => isBorder(table.adjacency, land.emoji, other.emoji))
      );
    };
    const canMove = lands
      .filter(land => land.color === attacker.color)
      .some(canAttack);
    const turnStart = canMove ? now() : now() - (TURN_SECONDS * 1000) / 2;

    const props = Object.assign(
      { turnStart: turnStart, attack: null },
      turnIndex !== undefined ? { turnIndex } : {}
    );
    publish.roll(
      { ...table, lands },
      {
        from: { emoji: table.attack.from, roll: fromRoll },
        to: { emoji: table.attack.to, roll: toRoll },
        turnStart: Math.floor(props.turnStart / 1000),
        players: players,
        capital: newCapital?.emoji ?? null,
      }
    );
    const result: CommandResult = {
      table: props,
      players,
      lands,
      eliminations,
    };

    if (players.length === 1) {
      return [
        result,
        { type: "EndGame", winner: players[0], turnCount: table.turnCount },
      ];
    }
    return [result, null];
  } catch (e) {
    logger.error(e);
    throw e;
  }
};
