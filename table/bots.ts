import * as R from "ramda";
import {
  Table,
  CommandResult,
  User,
  Persona,
  Player,
  Land,
  BotStrategy,
  BotPlayer,
  Color,
  BotState,
  IllegalMoveError,
} from "../types";
import { now, addSeconds, havePassed } from "../timestamp";
import * as publish from "./publish";
import { shuffle, rand } from "../rand";
import logger from "../logger";
import { GAME_START_COUNTDOWN, BOT_DEADLOCK_MAX } from "../constants";
import { makePlayer, flag } from "./commands";
import nextTurn from "./turn";
import { isBorder } from "../maps";
import { findLand, groupedPlayerPositions } from "../helpers";

const defaultPersona: Persona = {
  name: "Personality",
  picture: "assets/bot_profile_picture.svg",
  strategy: "RandomCareful",
  state: {
    deadlockCount: 0,
    lastAgressor: null,
  },
};

const personas: Persona[] = [
  { ...defaultPersona, name: "Mono", strategy: "Revengeful" },
  { ...defaultPersona, name: "Oliva", strategy: "RandomCareless" },
  { ...defaultPersona, name: "Cohete" },
  { ...defaultPersona, name: "Chiqui" },
  { ...defaultPersona, name: "Patata", strategy: "RandomCareless" },
  { ...defaultPersona, name: "Paleto" },
  { ...defaultPersona, name: "Cañón", strategy: "RandomCareless" },
  { ...defaultPersona, name: "Cuqui" },
];

export const isBot = (player: Player): player is BotPlayer =>
  player.bot !== null;

export const addBots = (table: Table): CommandResult => {
  const unusedPersonas = personas.filter(
    p =>
      !R.contains(
        p.name,
        table.players.filter(isBot).map(p => p.name)
      )
  );
  const persona = unusedPersonas[rand(0, unusedPersonas.length - 1)];
  const botUser: User = {
    id: `bot_${persona.name}`,
    name: persona.name,
    picture: persona.picture,
    level: 1,
    points: 100,
    email: "bot@skynet",
    networks: [],
    claimed: true,
  };
  const players = table.players.concat([
    {
      ...makePlayer(botUser, "bot", table.players.length),
      bot: persona,
      ready: true,
    },
  ]);

  let gameStart = table.gameStart;
  if (players.length >= table.startSlots) {
    gameStart = addSeconds(GAME_START_COUNTDOWN);

    publish.event({
      type: "countdown",
      table: table.name,
      players: players,
    });
  } else {
    publish.event({
      type: "join",
      table: table.name,
      player: { name: botUser.name },
    });
  }
  return {
    type: "Join",
    players,
    table: { gameStart },
  };
};

export const tickBotTurn = (table: Table): CommandResult => {
  if (!havePassed(0.5, table.turnStart)) {
    return { type: "Heartbeat" }; // fake noop
  }

  const player = table.players[table.turnIndex];
  if (!isBot(player)) {
    throw new Error("cannot tick non-bot");
  }

  if (
    table.players.every(p => p.bot !== null) ||
    player.bot.state.deadlockCount > BOT_DEADLOCK_MAX
  ) {
    const positions = groupedPlayerPositions(table);
    const position = positions(player);
    if (position > 1) {
      try {
        return flag(player, table);
      } catch (e) {
        logger.error("could not flag bot:", e);
        if (e instanceof IllegalMoveError) {
          return botNextTurn(table, player);
        } else {
          throw e;
        }
      }
    }
  }

  const sources = botSources(table, player);

  if (sources.length === 0) {
    return botNextTurn(table, player);
  }

  const attack = strategies(player.bot.strategy)(sources, player, table);

  if (attack === null) {
    return botNextTurn(table, player);
  }

  const emojiFrom = attack.from.emoji;
  const emojiTo = attack.to.emoji; // shuffled random

  const timestamp = now();
  publish.move(table, {
    from: emojiFrom,
    to: emojiTo,
  });
  return {
    type: "Attack",
    table: {
      turnStart: timestamp,
      turnActivity: true,
      attack: {
        start: timestamp,
        from: emojiFrom,
        to: emojiTo,
      },
    },
    players: table.players.map(p =>
      p === player ? setState(player, { deadlockCount: 0 }) : p
    ),
  };
};

const botNextTurn = (table: Table, bot: BotPlayer) => {
  const table_ = {
    ...table,
    players: table.players.map(p => {
      if (p === bot) {
        return setState(bot, {
          deadlockCount: bot.bot.state.deadlockCount + 1,
        });
      }
      return p;
    }),
  };
  return nextTurn("EndTurn", table_);
};

const setState = (p: BotPlayer, s: Partial<BotState>): BotPlayer => ({
  ...p,
  bot: {
    ...p.bot,
    state: {
      ...p.bot.state,
      ...s,
    },
  },
});

export const botsNotifyAttack = (table: Table): readonly Player[] =>
  table.players.map<Player>(player => {
    if (
      isBot(player) &&
      findLand(table.lands)(table.attack!.to).color === player.color
    ) {
      const lastAgressor = table.players.find(
        player =>
          player.color === findLand(table.lands)(table.attack!.from).color
      );

      return setState(player, { lastAgressor: lastAgressor?.id ?? null });
    }
    return player;
  });

type Source = { source: Land; targets: Land[] };
type Attack = { from: Land; to: Land; wheight: number };

const botSources = (table: Table, player: Player): Source[] => {
  const otherLands = table.lands.filter(other => other.color !== player.color);
  return shuffle(
    table.lands.filter(land => land.color === player.color && land.points > 1)
  )
    .map(source => ({
      source,
      targets: otherLands.filter(other =>
        isBorder(table.adjacency, source.emoji, other.emoji)
      ),
    }))
    .filter(attack => attack.targets.length > 0);
};

const strategies = (strategy: BotStrategy) => {
  switch (strategy) {
    default:
    case "RandomCareful":
      return (sources: Source[], _: BotPlayer, __: Table) =>
        sources.reduce<Attack | null>(
          (attack, { source, targets }) =>
            targets.reduce((attack, target) => {
              const bestChance = attack ? attack.wheight : -Infinity;
              // >
              const thisChance = source.points - target.points;
              if (thisChance > bestChance) {
                if (thisChance > 0) {
                  return { from: source, to: target, wheight: thisChance };
                }
              }
              // <
              return attack;
            }, attack),
          null
        );

    case "RandomCareless":
      return (sources: Source[], _: BotPlayer, __: Table) =>
        sources.reduce<Attack | null>(
          (attack, { source, targets }) =>
            targets.reduce((attack, target) => {
              const bestChance = attack ? attack.wheight : -Infinity;
              // >
              const thisChance = source.points - target.points;
              if (thisChance > bestChance) {
                return { from: source, to: target, wheight: thisChance };
              }
              // <
              return attack;
            }, attack),
          null
        );

    case "Revengeful":
      return (sources: Source[], player: BotPlayer, table: Table) =>
        sources.reduce<Attack | null>(
          (attack, { source, targets }) =>
            targets.reduce((attack, target) => {
              const bestChance = attack ? attack.wheight : -Infinity;
              // >
              const lastAgressorColor =
                table.players.find(p => p.id === player.bot.state.lastAgressor)
                  ?.color ?? null;

              if (lastAgressorColor) {
                if (target.color === lastAgressorColor) {
                  const thisChance = source.points - target.points;
                  if (thisChance > bestChance) {
                    return { from: source, to: target, wheight: thisChance };
                  }
                }
              } else if (target.color === Color.Neutral) {
                const thisChance = source.points - target.points;
                if (thisChance > bestChance) {
                  if (thisChance > 1) {
                    return { from: source, to: target, wheight: thisChance };
                  }
                }
              }
              // <
              return attack;
            }, attack),
          null
        );
  }
};
