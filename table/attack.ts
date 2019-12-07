import * as R from "ramda";
import { diceRoll } from "../rand";
import {
  findLand,
  updateLand,
  removePlayerCascade,
  tablePoints,
} from "../helpers";
import * as publish from "./publish";
import endGame from "./endGame";
import { Table, Land, CommandResult, Elimination } from "../types";
import { now } from "../timestamp";
import logger from "../logger";
import { botsNotifyAttack } from "./bots";
import { playerWithDerived } from "./serialize";
import { ELIMINATION_REASON_DIE } from "../constants";

export const rollResult = (table: Table): CommandResult => {
  if (!table.attack) {
    throw new Error(`rollResult without attack: ${table.attack}`);
  }
  try {
    const find = findLand(table.lands);
    const fromLand: Land = find(table.attack.from);
    const toLand = find(table.attack.to);
    const [fromRoll, toRoll, isSuccess] = diceRoll(
      fromLand.points,
      toLand.points
    );
    publish.roll(table, {
      from: { emoji: table.attack.from, roll: fromRoll },
      to: { emoji: table.attack.to, roll: toRoll },
    });
    let lands = table.lands;
    let players = botsNotifyAttack(table);
    let eliminations: ReadonlyArray<Elimination> | undefined = undefined;
    let turnIndex: number | undefined = undefined;
    if (isSuccess) {
      const loser = R.find(R.propEq("color", toLand.color), players);
      lands = updateLand(table.lands, toLand, {
        points: fromLand.points - 1,
        color: fromLand.color,
      });
      if (
        loser &&
        R.filter(R.propEq("color", loser.color), lands).length === 0
      ) {
        const attacker = players[table.turnIndex];
        [players, lands, turnIndex, eliminations] = removePlayerCascade(
          table,
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
      }
    }

    lands = updateLand(lands, fromLand, { points: 1 });

    const props = Object.assign(
      { turnStart: now(), attack: null },
      turnIndex !== undefined ? { turnIndex } : {}
    );
    const result: CommandResult = {
      type: "Roll",
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
    if (table.attack.clientId) {
      publish.clientError(table.attack.clientId, new Error("Roll failed"));
    }
    logger.error(e);
    throw e;
  }
};
