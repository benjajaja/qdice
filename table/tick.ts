import * as R from "ramda";
import * as Sentry from "@sentry/node";
import { getTable } from "./get";
import {
  Table,
  Player,
  Timestamp,
  Command,
  IllegalMoveError,
  Land,
} from "../types";
import { processCommand } from "../table";
import { havePassed } from "../timestamp";
import * as publish from "./publish";

import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  TURN_SECONDS,
  ROLL_SECONDS,
  ROLL_SECONDS_BOT,
} from "../constants";
import { addBots, tickBotTurn, isBot, mkBot } from "./bots";
import logger from "../logger";
import { setTimeout } from "timers";
import { findLand } from "../helpers";
import { diceRoll } from "../rand";

const intervalIds: { [tableTag: string]: any } = {};

const TICK_PERIOD_MS = 250;

export const start = (
  tableTag: string,
  lock: any,
  index: number,
  count: number
) => {
  setTimeout(() => {
    if (intervalIds[tableTag]) {
      throw new Error("already ticking");
    }
    intervalIds[tableTag] = setInterval(() => {
      try {
        tick(tableTag, lock);
      } catch (e) {
        logger.error("Tick error!", e);
      }
    }, TICK_PERIOD_MS);
  }, (TICK_PERIOD_MS / count) * index);
};

export const stop = (tableTag: string) => {
  if (intervalIds[tableTag] === null) {
    throw new Error("cannot stop, not ticking");
  }
  clearInterval(intervalIds[tableTag]);
  delete intervalIds[tableTag];
};

const tick = async (tableTag: string, lock) => {
  if (lock.isBusy(tableTag)) {
    return;
  }

  lock.acquire(tableTag, async done => {
    const table = await getTable(tableTag);
    let command: Command | void = undefined;
    if (table.status === STATUS_PLAYING) {
      if (table.players.length === 0) {
        logger.error("STATUS_PLAYING but no players!");
        Sentry.captureException(new Error("STATUS_PLAYING but no players!"));
        command = { type: "EndGame", winner: null, turnCount: table.turnCount };
        // result = endGame(table, { type: "TickTurnOver" });
      } else if (!table.players[table.turnIndex]) {
        logger.error(
          "turnIndex out of bounds!",
          table.turnIndex,
          table.players
        );
        Sentry.captureException(
          new Error(
            `STATUS_PLAYING and no turn player: ${
              table.turnIndex
            }, ${table.players.map(p => p.name).join()}`
          )
        );
        command = { type: "TickTurnOver", sitPlayerOut: false };
      } else if (table.attack) {
        if (
          havePassed(
            table.players[table.turnIndex].bot
              ? ROLL_SECONDS_BOT
              : ROLL_SECONDS,
            table.attack.start
          )
        ) {
          const [fromRoll, toRoll, _, toLand] = rollDice(table);
          const defender =
            table.players.find(p => p.color === toLand.color) ?? null;
          command = {
            type: "Roll",
            attacker: table.players[table.turnIndex],
            defender,
            from: table.attack.from,
            to: table.attack.to,
            fromRoll,
            toRoll,
          };
        }
        // never process anything else during attack
      } else if (table.players[table.turnIndex].out) {
        command = { type: "TickTurnOut" };
      } else if (havePassed(TURN_SECONDS, table.turnStart)) {
        command = { type: "TickTurnOver", sitPlayerOut: !table.turnActivity };
      } else if (table.players.every(R.prop("out"))) {
        command = { type: "TickTurnAllOut" };
      } else if (table.players[table.turnIndex].bot !== null) {
        command = tickBotTurn(table);
      }
    } else if (table.status === STATUS_PAUSED) {
      if (shouldStart(table)) {
        command = { type: "Start" };
      } else if (
        !table.params.botLess &&
        table.players.filter(R.complement(isBot)).length > 0 &&
        table.players.length < table.startSlots &&
        havePassed(3, lastJoined(table.players))
      ) {
        const persona =
          table.name === "Planeta" &&
          table.players.length === table.playerSlots - 1
            ? mkBot("Covid-19", "RandomCareful", "assets/bots/bot_covid19.png")
            : undefined;
        command = addBots(table, persona);
      }
    }

    if (command === undefined) {
      command = { type: "Clear" }; // cleanWatchers(table);
    }

    try {
      await processCommand(table, command);
    } catch (e) {
      if (e instanceof IllegalMoveError) {
        logger.error(
          e,
          e.bot,
          "illegal move from tick caught gracefully",
          command
        );
        Sentry.captureException(e);
      } else {
        await publish.sigint();
        throw e;
      }
    } finally {
      done();
    }
  });
};

const shouldStart = (table: Table) => {
  if (table.players.filter(isBot).length >= table.playerSlots) {
    return true;
  }
  if (
    table.players.length >= table.startSlots &&
    table.players.every(player => player.ready)
  ) {
    return true;
  }
  if (countdownFinished(table.gameStart)) {
    return true;
  }
  return false;
};

const countdownFinished = (gameStart: number) =>
  gameStart !== 0 && havePassed(0, gameStart);

const lastJoined = (players: ReadonlyArray<Player>): Timestamp => {
  const last = R.reduce<Timestamp, Timestamp>(
    R.max,
    0,
    players
      .filter(player => player.bot === null)
      .map<Timestamp>(player => player.joined)
  );
  return last;
};

const rollDice = (table: Table): [number[], number[], Land, Land] => {
  const find = findLand(table.lands);
  const fromLand = find(table.attack!.from);
  const toLand = find(table.attack!.to);
  if (table.roundCount === 1 && fromLand.points > toLand.points) {
    const fromRoll = R.range(0, fromLand.points).map(R.always(6));
    const toRoll = R.range(0, toLand.points).map(R.always(6));
    return [fromRoll, toRoll, fromLand, toLand];
  }
  const [fromRoll, toRoll, _] = diceRoll(fromLand.points, toLand.points);
  return [fromRoll, toRoll, fromLand, toLand];
};
