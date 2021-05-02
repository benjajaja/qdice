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
  IllegalMoveError,
  Command,
  User,
  CommandType,
  Player,
  BotPlayer,
  IllegalMoveCode,
  UserId,
  Adjacency,
  Land,
} from "./types";
import * as db from "./db";
import * as publish from "./table/publish";
import * as tick from "./table/tick";
import { getTable, getTableTags, deleteTable } from "./table/get";
import { startGameEvent } from "./table/games";
import {
  startGame,
  preloadStartingPositions,
  setGameStart,
} from "./table/start";
import {
  cleanWatchers,
  cleanPlayers,
  heartbeat,
  enter,
  exit,
} from "./table/watchers";
import { assertNever, giveDice } from "./helpers";
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
import endGame from "./table/endGame";
import { rollResult } from "./table/attack";
import { botState } from "./table/bots";
import { processEliminations } from "./table/eliminations";
import { STATUS_PLAYING } from "./constants";

const verifyJwt = promisify(jwt.verify);

export const startTables = async (lock: AsyncLock, client: mqtt.MqttClient) => {
  const runningTableTags: string[] = await getTableTags();
  const deleteTables = runningTableTags.filter(tag =>
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
          let lands: readonly Land[] = table.lands;
          let maybeMapChange = {};
          if (table.status !== STATUS_PLAYING && !params.tournament) {
            lands = maps.hasChanged(table.mapName, table.lands);
            const [_, adjacency] = maps.loadMap(mapName);
            maybeMapChange = { mapName, adjacency };
          }
          await save(
            table,
            {
              ...maybeMapChange,
              name,
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
          await deleteTable(tag);
        })
      )
  );
};

const start = async (
  tableTag: string,
  lock: AsyncLock,
  client: mqtt.MqttClient,
  index: number,
  count: number
) => {
  const table = await getTable(tableTag);
  publish.tableStatus(table);

  client.subscribe(`tables/${tableTag}/server`);

  const onMessage = async (topic: string, message: string) => {
    if (topic !== `tables/${tableTag}/server`) {
      return;
    }

    const parsedMessage = parseMessage(message.toString(), topic);
    if (!parsedMessage) {
      return;
    }

    const isTwitter = !!table.params.twitter;
    const { type, clientId, token, payload } = parsedMessage;

    lock.acquire(tableTag, async done => {
      try {
        let user: User | null = null;
        if (isTwitter) {
          user = parsedMessage.user ?? null;
        } else {
          user = (await (token
            ? verifyJwt(token, process.env.JWT_SECRET!)
            : null)) as User | null;
        }

        const table = await getTable(tableTag);

        const userCommand = toCommand(table, user, clientId, type, payload);
        await processCommand(table, userCommand);
      } catch (e) {
        publish.clientError(clientId, e);
        if (e instanceof IllegalMoveError) {
          logger.error(e, e.code, e.bot, "illegal move caught gracefully");
          // Ignore a bunch of errors that are not unexpected or probably due to client/server delay
          switch (e.code) {
            case IllegalMoveCode.IsRetired:
            case IllegalMoveCode.NotEnoughPoints:
            case IllegalMoveCode.EndTurnOutOfTurn:
            case IllegalMoveCode.JoinWhilePlaying:
            case IllegalMoveCode.AttackOutOfTurn:
            case IllegalMoveCode.ReadyWhilePlaying:
            case IllegalMoveCode.EndTurnDuringAttack:
              break;
            default: {
              Sentry.setTag("IllegalMoveSource", "user-command");
              Sentry.setTag("IllegalMoveCode", e.code.toString());
              Sentry.setTag("isBot", e.bot ? "yes" : "no");
              Sentry.captureException(e);
            }
          }
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
  message: string,
  topic: string
): {
  type: CommandType;
  clientId: string;
  token: string;
  payload: any | undefined;
  user: User | undefined;
} | null => {
  try {
    const { type, client: clientId, token, payload, user } = JSON.parse(
      message.toString()
    );
    return { type, clientId, token, payload, user };
  } catch (e) {
    logger.error(
      `Could not parse message in ${topic}:`,
      message.toString().slice(0, 50)
    );
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
      return {
        type: "EndTurn",
        player: findPlayer(type, table, user),
        dice: giveDice(table),
        sitPlayerOut: false,
      };
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
      return {
        type: "Flag",
        player: findPlayer(type, table, user),
        position: payload as number,
      };
    case "Heartbeat":
      return { type: "Heartbeat", user, clientId };
    default:
      throw new Error(`unknown command "${type}"`);
  }
};
const assertUser = (type: CommandType, user: User | null): User => {
  if (user === null) {
    throw new IllegalMoveError(
      `user is null (for command "${type}")`,
      IllegalMoveCode.UserIsNull
    );
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
    throw new IllegalMoveError("not playing", IllegalMoveCode.NotPlaying);
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
      return endTurn(command.player, table, command.sitPlayerOut, command.dice);
    case "SitOut":
      return [sitOut(command.player, table), null];
    case "SitIn":
      return [sitIn(command.player, table), null];
    case "Chat":
      return [chat(command.user, table, command.message), null];
    case "ToggleReady":
      return toggleReady(command.player, table, command.ready);
    case "Flag":
      return flag(command.player, command.position, table);
    case "Heartbeat":
      return [heartbeat(command.user, table, command.clientId), null];
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
    case "SetGameStart":
      return [
        setGameStart(table, command.gameStart, command.returnFee, command.map),
        null,
      ];
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
      payScores,
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
      await processEliminations(
        newTable,
        eliminations,
        players ?? newTable.players,
        newTable.currentGame ?? table.currentGame
      );
    }
    if (payScores) {
      await processPayScores(newTable, payScores);
    }
    if (
      [
        "Join",
        "Leave",
        "Start",
        "EndGame",
        "ToggleReady",
        "SetGameStart",
      ].indexOf(command.type) !== -1
    ) {
      publish.tableStatus(newTable);
    }
  }

  if (
    ["Heartbeat", "Clear"].indexOf(command.type) === -1 &&
    (table.currentGame ?? gameId)
  ) {
    publish.gameEvent(table.tag, (table.currentGame ?? gameId)!, command);
  }

  if (command.type !== "Heartbeat") {
    publish.eventFromCommand(newTable, command, result);
  }

  if (next !== null) {
    newTable = await processCommand(newTable, next);
  }
  return newTable;
};

const processPayScores = async (
  table: Table,
  scores: readonly [UserId, string | null, number][]
): Promise<void> => {
  for (const payScore of scores) {
    const [userId, clientId, score] = payScore;
    logger.debug("processPayScore", userId, clientId, score);
    try {
      const user_ = await db.addScore(userId, score);
      const preferences = await db.getPreferences(userId);
      if (clientId) {
        publish.userUpdate(clientId)(user_, preferences);
        publish.userMessage(
          clientId,
          `You have ${score < 0 ? "payed" : "received back"} ${Math.abs(
            score
          )} points for a game in table ${table.name}.`
        );
      } else {
        logger.error("Cannot publish userUpdate (no clientId)");
      }
    } catch (e) {
      // send a message to this specific player
      if (clientId) {
        publish.clientError(
          clientId,
          new Error(
            `You ${score >= 0 ? "earned" : "lost"} ${Math.abs(
              score
            )} points, but I failed to set them on your profile.`
          )
        );
      } else {
        logger.error("Cannot publish clientError (no clientId)");
      }
    }
  }
};
