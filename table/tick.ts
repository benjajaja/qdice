import * as R from "ramda";
import { getTable } from "./get";
import { Table, Player, CommandResult, Timestamp } from "../types";
import { processComandResult } from "../table";
import { havePassed } from "../timestamp";

import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  TURN_SECONDS,
  ROLL_SECONDS,
} from "../constants";
import * as publish from "./publish";
import nextTurn from "./turn";
import startGame from "./start";
import { rollResult } from "./attack";
import { addBots, tickBotTurn, isBot } from "./bots";
import { leave } from "./commands";
import logger from "../logger";

const intervalIds: { [tableTag: string]: any } = {};

export const start = (tableTag: string, lock: any) => {
  if (intervalIds[tableTag]) {
    throw new Error("already ticking");
  }
  intervalIds[tableTag] = setInterval(() => {
    try {
      tick(tableTag, lock);
    } catch (e) {
      logger.error("Tick error!", e);
    }
  }, 500);
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
    let result: CommandResult | void = undefined;
    if (table.status === STATUS_PLAYING) {
      if (table.attack) {
        if (havePassed(ROLL_SECONDS, table.attack.start)) {
          result = rollResult(table);
        }
        // never process anything else during attack
      } else if (table.players[table.turnIndex].out) {
        result = nextTurn("TickTurnOut", table);
      } else if (havePassed(TURN_SECONDS, table.turnStart)) {
        result = nextTurn("TickTurnOver", table, !table.turnActivity);
      } else if (table.players.every(R.prop("out"))) {
        result = nextTurn("TickTurnAllOut", table);
      } else if (table.players[table.turnIndex].bot !== null) {
        result = tickBotTurn(table);
      }
    } else if (table.status === STATUS_PAUSED) {
      if (shouldStart(table)) {
        result = startGame(table);
      } else if (
        table.players.filter(R.complement(isBot)).length > 0 &&
        table.players.length < table.startSlots &&
        havePassed(3, lastJoined(table.players))
      ) {
        result = addBots(table);
      } else if (table.players.length > 0) {
        result = cleanPlayers(table);
      }
    }

    if (result === undefined) {
      result = cleanWatchers(table);
    }

    await processComandResult(table, result);
    done();
  });
};

const shouldStart = (table: Table) =>
  table.players.length >= table.startSlots &&
  (countdownFinished(table.gameStart) ||
    table.players.every(player => player.ready));

const countdownFinished = (gameStart: number) =>
  gameStart !== 0 && havePassed(0, gameStart);

const checkWatchers = <T extends { lastBeat: Timestamp }>(
  watchers: ReadonlyArray<T>,
  seconds: number
): [ReadonlyArray<T>, ReadonlyArray<T>] => {
  return watchers.reduce(
    ([yes, no], watcher) => {
      if (!havePassed(seconds, watcher.lastBeat)) {
        return [R.append(watcher, yes), no];
      } else {
        return [yes, R.append(watcher, no)];
      }
    },
    [[], []] as any
  );
};

const cleanWatchers = (table: Table): CommandResult | undefined => {
  const [stillWatching, stoppedWatching] = checkWatchers(table.watching, 30);
  if (stoppedWatching.length > 0) {
    stoppedWatching.forEach(user => publish.exit(table, user.name));
    return {
      type: "CleanWatchers",
      watchers: stillWatching,
    };
  }
  return undefined;
};

const cleanPlayers = (table: Table): CommandResult | undefined => {
  const [_, stoppedWatching] = checkWatchers(table.players, 60 * 5);
  if (stoppedWatching.length > 0) {
    return leave(stoppedWatching[0], table);
  }

  if (table.players.length > 0) {
    const bots = table.players.filter(isBot);
    if (bots.length > 0) {
      if (
        bots.length === table.players.length ||
        table.players.length > table.startSlots
      ) {
        return leave(bots[0], table);
      }
    }
  }
  return undefined;
};

const lastJoined = (players: ReadonlyArray<Player>): Timestamp => {
  const last = R.reduce<Timestamp, Timestamp>(
    R.max,
    0,
    players
      .filter(player => player.bot === null)
      .map<Timestamp>(player => player.joined)
  );
  logger.debug("last", last);
  return last;
};
