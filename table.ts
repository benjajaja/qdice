import { promisify } from "util";
import * as R from "ramda";
import * as mqtt from "mqtt";
import * as jwt from "jsonwebtoken";
import * as AsyncLock from "async-lock";
import * as Sentry from "@sentry/node";

import * as maps from "./maps";
import {
  Table,
  CommandResult,
  Elimination,
  IllegalMoveError,
  Command,
  User,
  CommandType,
  Player,
  BotPlayer,
} from "./types";
import * as db from "./db";
import * as publish from "./table/publish";
import * as tick from "./table/tick";
import { getTable } from "./table/get";
import { addGameEvent, startGameEvent } from "./table/games";
import nextTurn from "./table/turn";
import { startGame, preloadStartingPositions } from "./table/start";
import {
  cleanWatchers,
  cleanPlayers,
  heartbeat,
  enter,
  exit,
} from "./table/watchers";
import { positionScore, tablePoints, assertNever } from "./helpers";
import logger from "./logger";
import * as config from "./tables.config";

import {
  join,
  leave,
  attack,
  endTurn,
  sitOut,
  sitIn,
  chat,
  toggleReady,
  flag,
} from "./table/commands";
import { save } from "./table/get";
import { STATUS_FINISHED } from "./constants";
import endGame from "./table/endGame";
import { rollResult } from "./table/attack";
import { botState } from "./table/bots";

const verifyJwt = promisify(jwt.verify);

export const startTables = async (lock: AsyncLock, client: mqtt.MqttClient) => {
  const tables: string[] = (await db.getTablesStatus()).map(
    status => status.tag
  );
  const deleteTables = tables.filter(tag =>
    R.not(
      R.contains(
        tag,
        config.tables.map(t => t.tag)
      )
    )
  );
  await Promise.all(
    config.tables
      .map(
        async (
          {
            tag,
            name,
            mapName,
            playerSlots,
            startSlots,
            points,
            stackSize,
            params,
          },
          index: number
        ) => {
          const table = await getTable(tag);
          const lands = maps.hasChanged(table.mapName, table.lands);
          await save(
            table,
            {
              name,
              mapName,
              playerSlots,
              startSlots,
              points,
              stackSize,
              params,
            },
            undefined,
            lands,
            undefined,
            undefined
          );
          await preloadStartingPositions(table.mapName);
          await start(table.tag, lock, client, index, config.tables.length);
        }
      )
      .concat(
        deleteTables.map(async tag => {
          logger.warn(`Deleting table: "${tag}"`);
          await db.deleteTable(tag);
        })
      )
  );
};

export const start = async (
  tableTag: string,
  lock: AsyncLock,
  client: mqtt.MqttClient,
  index: number,
  count: number
) => {
  publish.tableStatus(await getTable(tableTag));

  client.subscribe(`tables/${tableTag}/server`);

  const onMessage = async (topic, message) => {
    if (topic !== `tables/${tableTag}/server`) {
      return;
    }

    const parsedMessage = parseMessage(message.toString());
    if (!parsedMessage) {
      return;
    }

    const { type, clientId, token, payload } = parsedMessage;

    lock.acquire(tableTag, async done => {
      try {
        const user = (await (token
          ? verifyJwt(token, process.env.JWT_SECRET!)
          : null)) as User | null;
        const table = await getTable(tableTag);

        const userCommand = toCommand(table, user, clientId, type, payload);
        await processCommand(table, userCommand);
      } catch (e) {
        publish.clientError(clientId, e);
        if (e instanceof IllegalMoveError) {
          logger.error(e, e.bot, "illegal move caught gracefully");
          Sentry.captureException(e);
        } else if (e instanceof jwt.JsonWebTokenError) {
          logger.error(e, "bad JWT token");
          Sentry.captureException(e);
        } else {
          throw e;
        }
      } finally {
        done();
      }
    });
  };

  client.on("message", onMessage);

  // await db.clearGames(lock);
  tick.start(tableTag, lock, index, count);
  return () => {
    client.off("message", onMessage);
    tick.stop(tableTag);
  };
};

const parseMessage = (
  message: string
): {
  type: CommandType;
  clientId: string;
  token: string;
  payload: any | undefined;
} | null => {
  try {
    const { type, client: clientId, token, payload } = JSON.parse(
      message.toString()
    );
    return { type, clientId, token, payload };
  } catch (e) {
    logger.error(e, "Could not parse message");
    return null;
  }
};

const toCommand = (
  table: Table,
  user: User | null,
  clientId: string,
  type: CommandType,
  payload: unknown
): Command => {
  switch (type) {
    case "Enter":
      return { type: "Enter", user, clientId };
    case "Exit":
      return { type: "Exit", user, clientId };
    case "Join":
      return {
        type: "Join",
        user: assertUser(type, user),
        clientId,
        bot: null,
      };
    case "Leave":
      return { type: "Leave", player: findPlayer(type, table, user) };
    case "Attack":
      const [from, to] = payload as [string, string];
      return {
        type: "Attack",
        player: findPlayer(type, table, user),
        from,
        to,
      };
    case "EndTurn":
      return { type: "EndTurn", player: findPlayer(type, table, user) };
    case "SitOut":
      return { type: "SitOut", player: findPlayer(type, table, user) };
    case "SitIn":
      return { type: "SitIn", player: findPlayer(type, table, user) };
    case "Chat":
      return {
        type: "Chat",
        user,
        message: payload as string,
      };
    case "ToggleReady":
      return {
        type: "ToggleReady",
        player: findPlayer(type, table, user),
        ready: payload as boolean,
      };
    case "Flag":
      return { type: "Flag", player: findPlayer(type, table, user) };
    case "Heartbeat":
      return { type: "Heartbeat", user, clientId };
    default:
      throw new Error(`unknown command "${type}"`);
  }
};
const assertUser = (type: CommandType, user: User | null): User => {
  if (user === null) {
    throw new IllegalMoveError(`user is null (for command "${type}")`);
  }
  return user;
};
const findPlayer = (
  type: CommandType,
  table: Table,
  user: User | null
): Player => {
  const u = assertUser(type, user);
  const existing = table.players.filter(p => p.id === u.id).pop();
  if (!existing) {
    throw new IllegalMoveError("not playing");
  }
  return existing;
};

const commandResult = async (
  table: Table,
  command: Command
): Promise<[CommandResult | null, Command | null]> => {
  switch (command.type) {
    case "Enter":
      return [enter(command.user, table, command.clientId), null];
    case "Exit":
      return [exit(command.user, table, command.clientId), null];
    case "Join":
      return [join(command.user, table, command.clientId, command.bot), null];
    case "Leave":
      return [leave(command.player, table), null];
    case "Attack":
      return [attack(command.player, table, command.from, command.to), null];
    case "EndTurn":
      return endTurn(command.player, table);
    case "SitOut":
      return [sitOut(command.player, table), null];
    case "SitIn":
      return [sitIn(command.player, table), null];
    case "Chat":
      return [chat(command.user, table, command.message), null];
    case "ToggleReady":
      return [toggleReady(command.player, table, command.ready), null];
    case "Flag":
      return flag(command.player, table);
    case "Heartbeat":
      return [heartbeat(command.user, table, command.clientId), null];
    case "TickTurnOver":
      return nextTurn(table, command.sitPlayerOut);
    case "TickTurnOut":
      return nextTurn(table);
    case "TickTurnAllOut":
      return nextTurn(table);
    case "EndGame":
      return [endGame(table, command.winner, command.turnCount), null];
    case "Roll":
      return rollResult(table, command.fromRoll, command.toRoll);
    case "Start":
      return [startGame(table), null];
    case "Clear":
      return [cleanPlayers(table) || cleanWatchers(table), null];
    case "BotState":
      return botState(table, command.player as BotPlayer, command.botCommand);
    default:
      return assertNever(command);
  }
};

export const processCommand = async (table: Table, command: Command) => {
  let [result, next] = await commandResult(table, command);
  let newTable = table;

  let gameId: number | null = null;
  if (command.type === "Start") {
    gameId = await startGameEvent(table, result);
  }

  if (result !== null) {
    const {
      table: props,
      lands,
      players,
      watchers,
      eliminations,
      retired, // only from endGame
    } = result;

    newTable = await save(
      table,
      gameId ? { ...props, currentGame: gameId } : props,
      players,
      lands,
      watchers,
      retired
        ? retired
        : eliminations
        ? table.retired.concat(
            eliminations.filter(e => !e.player.bot).map(e => e.player)
          )
        : undefined
    );
    if (eliminations) {
      await processEliminations(newTable, eliminations);
    }
    if (["Join", "Leave", "Start", "EndGame"].indexOf(command.type) !== -1) {
      logger.debug(`tableStatus: ${command.type}`);
      logger.debug(`players: ${newTable.players.length}`);
      publish.tableStatus(newTable);
    }
  }

  if (
    ["Heartbeat", "Clear"].indexOf(command.type) === -1 &&
    (table.currentGame ?? gameId)
  ) {
    publish.gameEvent(table.tag, (table.currentGame ?? gameId)!, command);
  }

  if (next !== null) {
    newTable = await processCommand(newTable, next);
  }
  return newTable;
};

const processEliminations = async (
  table: Table,
  eliminations: ReadonlyArray<Elimination>
): Promise<void> => {
  return Promise.all(
    eliminations.map(async elimination => {
      const { player, position, reason, source } = elimination;

      const score =
        player.score +
        positionScore(tablePoints(table))(table.playerStartCount)(position);

      publish.elimination(table, player, position, score, reason, source);
      publish.event({
        type: "elimination",
        table: table.name,
        player,
        position,
        score,
      });

      logger.debug("ELIMINATION-------------");
      logger.debug(position, player.name, player.score, score);
      if (player.bot === null) {
        try {
          const user = await db.addScore(player.id, score);
          const preferences = await db.getPreferences(player.id);
          publish.userUpdate(player.clientId)(user, preferences);
        } catch (e) {
          // send a message to this specific player
          publish.clientError(
            player.clientId,
            new Error(
              `You earned ${score} points, but I failed to add them to your profile.`
            )
          );
          throw e;
        }
      }
    })
  ).then(() => undefined);
};
