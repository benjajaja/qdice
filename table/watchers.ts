import { Table, CommandResult, Timestamp } from "../types";
import * as publish from "./publish";
import { leave } from "./commands";
import { havePassed } from "../timestamp";
import * as R from "ramda";
import { isBot } from "./bots";
import { STATUS_PLAYING } from "../constants";

export const cleanWatchers = (table: Table): CommandResult | null => {
  const [stillWatching, stoppedWatching] = checkWatchers(table.watching, 30);
  if (stoppedWatching.length > 0) {
    stoppedWatching.forEach(user => publish.exit(table, user.name));
    return {
      type: "CleanWatchers",
      watchers: stillWatching,
    };
  }
  return null;
};

export const cleanPlayers = (table: Table): CommandResult | null => {
  if (table.status === STATUS_PLAYING) {
    return null;
  }
  const [_, stoppedWatching] = checkWatchers(table.players, 60 * 5);
  if (stoppedWatching.length > 0) {
    return leave(stoppedWatching[0], table);
  }

  return removeBots(table);
};

export const checkWatchers = <T extends { lastBeat: Timestamp }>(
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

const removeBots = (table: Table): CommandResult | null => {
  if (table.players.length > 0) {
    const bots = table.players.filter(isBot);
    if (bots.length > 0) {
      if (
        (table.name === "Planeta"
          ? bots.length === table.players.length + 1
          : bots.length === table.players.length) ||
        table.players.length > table.startSlots
      ) {
        return leave(R.last(bots)!, table);
      }
    }
  }
  return null;
};
