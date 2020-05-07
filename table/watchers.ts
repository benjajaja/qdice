import { Table, CommandResult, Timestamp, User, Watcher } from "../types";
import * as publish from "./publish";
import { leave } from "./commands";
import { havePassed, now } from "../timestamp";
import * as R from "ramda";
import { isBot } from "./bots";
import { STATUS_PLAYING } from "../constants";
import logger from "../logger";

import * as config from "../tables.config";
import { getTable, save, getChat } from "./get";
import AsyncLock = require("async-lock");

export const death = (lock: AsyncLock) => async (clientId: string) => {
  const tags: string[] = config.tables.map(t => t.tag);
  for (let tag of tags) {
    await lock.acquire(tag, async done => {
      const table = await getTable(tag);
      for (let watcher of table.watching) {
        if (watcher.clientId === clientId) {
          await save(
            table,
            undefined,
            undefined,
            undefined,
            table.watching.map(w => {
              if (w === watcher) {
                return { ...watcher, death: now() };
              }
              return w;
            })
          );
          return done();
        }
      }
      return done();
    });
  }
};

export const heartbeat = (
  user: User | null,
  table: Table,
  clientId: string
): CommandResult => {
  const finder =
    user && user.id ? R.propEq("id", user.id) : R.propEq("clientId", clientId);

  const existing = R.find(finder, table.watching);
  const watching: ReadonlyArray<Watcher> = existing
    ? table.watching.map(watcher =>
        finder(watcher)
          ? Object.assign({}, watcher, { lastBeat: now() })
          : watcher
      )
    : table.watching.concat([
        {
          clientId,
          id: user && user.id ? user.id : null,
          name: user ? user.name : null,
          lastBeat: now(),
          death: 0,
        },
      ]);

  return { watchers: watching };
};

export const enter = (
  user: User | null,
  table: Table,
  clientId: string
): CommandResult | null => {
  publish.tableStatus(table, clientId);
  const chatlines = getChat(table);
  if (chatlines.length > 0) {
    publish.chat(table, chatlines, clientId);
  }
  const existing = R.find(R.propEq("clientId", clientId), table.watching);
  if (!existing) {
    publish.enter(table, user ? user.name : null);
    return {
      watchers: R.append(
        {
          clientId,
          id: user && user.id ? user.id : null,
          name: user ? user.name : null,
          lastBeat: now(),
          death: 0,
        },
        table.watching
      ),
    };
  } else if (existing.death !== 0) {
    return {
      watchers: table.watching.map(w =>
        w === existing ? { ...w, death: 0 } : w
      ),
    };
  }
  return null;
};

export const exit = (
  user: User | null,
  table: Table,
  clientId: string
): CommandResult | null => {
  const existing = table.watching.find(R.propEq("clientId", clientId));
  if (existing) {
    if (
      existing.id !== null &&
      !table.players.find(player => player.id === existing.id)
    ) {
      publish.exit(table, user ? user.name : null);
    }
    return {
      watchers: R.filter(
        R.complement(R.propEq("clientId", clientId)),
        table.watching
      ),
    };
  }
  return null;
};

export const cleanWatchers = (table: Table): CommandResult | null => {
  const [stillWatching, stoppedWatching] = checkWatchers(table.watching, w => {
    if (w.death > 0) {
      return [1, w.death];
    } else {
      return [30, w.lastBeat];
    }
  });
  if (stoppedWatching.length > 0) {
    stoppedWatching.forEach(user => {
      if (
        user.id !== null &&
        !table.players.find(player => player.id === user.id)
      ) {
        publish.exit(table, user.name);
      }
    });
    return {
      watchers: stillWatching,
    };
  }
  return null;
};

export const cleanPlayers = (table: Table): CommandResult | null => {
  if (!table.params.tournament && table.status !== STATUS_PLAYING) {
    const [_, stoppedWatching] = checkWatchers(table.players, p => [
      60 * 20,
      p.lastBeat,
    ]);
    if (stoppedWatching.length > 0) {
      return leave(stoppedWatching[0], table);
    }
  }

  return removeBots(table);
};

export const checkWatchers = <T>(
  watchers: readonly T[],
  getter: (t: T) => [number, number]
): [readonly T[], readonly T[]] => {
  return watchers.reduce(
    ([yes, no], watcher) => {
      if (!havePassed(...getter(watcher))) {
        return [R.append(watcher, yes), no];
      } else {
        return [yes, R.append(watcher, no)];
      }
    },
    [[], []] as [readonly T[], readonly T[]]
  );
};

const removeBots = (table: Table): CommandResult | null => {
  if (table.status !== STATUS_PLAYING) {
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
  }
  return null;
};
