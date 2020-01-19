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
import { setTimeout } from "timers";

const intervalIds: { [tableTag: string]: any } = {};

const TICK_PERIOD_MS = 500;

export const start = (tableTag: string, lock: any, index, count) => {
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
    let result: CommandResult | void = undefined;
    if (table.status === STATUS_PLAYING) {
      if (table.turnIndex >= table.players.length) {
        logger.error(
          "turnIndex out of bounds!",
          table.turnIndex,
          table.players
        );
        result = nextTurn("TickTurnOver", {
          ...table,
          turnIndex: table.players.length - 1,
        });
      } else if (table.attack) {
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
        !table.params.botLess &&
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

const shouldStart = (table: Table) => {
  if (table.players.filter(isBot).length >= table.startSlots) {
    return true;
  }
  if (
    table.players.filter(R.complement(isBot)).length >= table.startSlots ||
    (table.players.length >= table.startSlots &&
      table.players.every(player => player.ready))
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

  return removeBots(table);
};

const removeBots = (table: Table): CommandResult | undefined => {
  if (table.players.length > 0) {
    const bots = table.players.filter(isBot);
    if (bots.length > 0) {
      if (
        bots.length === table.players.length ||
        table.players.length > table.startSlots
      ) {
        return leave(R.last(bots)!, table);
      }
    }
  }
};

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
