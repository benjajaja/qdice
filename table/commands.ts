import * as R from "ramda";
import {
  UserId,
  Table,
  Land,
  User,
  Player,
  CommandResult,
  IllegalMoveError,
  Elimination,
  UserLike,
  BotPlayer,
  Color,
  Persona,
  Command,
} from "../types";
import * as publish from "./publish";
import { addSeconds, now } from "../timestamp";
import {
  hasTurn,
  findLand,
  adjustPlayer,
  groupedPlayerPositions,
  removePlayerCascade,
  tablePoints,
} from "../helpers";
import { isBorder } from "../maps";
import nextTurn from "./turn";
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  COLOR_NEUTRAL,
  GAME_START_COUNTDOWN,
  ELIMINATION_REASON_SURRENDER,
  GAME_START_COUNTDOWN_FULL,
} from "../constants";
import logger from "../logger";
import { isBot, tableThemed } from "./bots";

export const makePlayer = (
  user: User,
  clientId: string,
  players: readonly Player[],
  forceColor?: Color
): Player => {
  const taken = R.complement(
    R.contains(
      R.__,
      players.map(p => p.color)
    )
  );
  const color = forceColor ?? R.head(R.range(1, 10).filter(taken));
  if (color === undefined) {
    logger.error("cannot find untaken color", players);
    throw new Error("cannot find unused color on join");
  }

  return {
    id: user.id,
    clientId,
    name: user.name,
    picture: user.picture || "",
    color,
    reserveDice: 0,
    out: false,
    outTurns: 0,
    points: user.points,
    awards: user.awards,
    rank: user.rank,
    level: user.level,
    position: 0,
    score: 0,
    flag: null,
    lastBeat: now(),
    joined: now(),
    ready: false,
    bot: null,
  };
};

export const join = (
  user: User,
  table: Table,
  clientId: string | null,
  bot: Persona | null
): CommandResult => {
  if (table.status === STATUS_PLAYING) {
    if (clientId !== null && table.players.some(isBot)) {
      return takeover(user, table, clientId);
    }
    throw new IllegalMoveError("join while STATUS_PLAYING", !!bot);
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (existing) {
    throw new IllegalMoveError("already joined", !!bot);
  }

  if (bot === null && user.points < table.points) {
    throw new IllegalMoveError("not enough points to join", !!bot);
  }

  if (!table.players.some(isBot) && table.players.length >= table.playerSlots) {
    throw new IllegalMoveError("table already full", !!bot);
  }

  let result: [readonly Player[], Player];
  if (bot !== null) {
    const player = {
      ...tableThemed(table, makePlayer(user, "bot", table.players)),
      bot,
      ready: process.env.NODE_ENV === "local",
    };
    const players = R.sortBy(R.prop("color"), table.players.concat([player]));
    result = [players, player];
  } else {
    logger.debug("join", typeof user.id);
    const [players, player, removed] = insertPlayer(
      table.players,
      user,
      clientId
    );
    if (!R.equals(players, R.sortBy(R.prop("color"), players))) {
      logger.error(
        "bad sort",
        table.players.map(p => [p.name, p.color]),
        players.map(p => [p.name, p.color])
      );
    }

    if (removed) {
      publish.leave(table, removed);
    }
    result = [players, player];
  }

  const [players, player] = result;

  const status =
    table.status === STATUS_FINISHED ? STATUS_PAUSED : table.status;
  const lands =
    table.status === STATUS_FINISHED
      ? table.lands.map(land =>
          Object.assign({}, land, {
            points: 1,
            color: -1,
          })
        )
      : table.lands;
  const turnCount = table.status === STATUS_FINISHED ? 1 : table.turnCount;

  let gameStart = table.gameStart;

  publish.join(table, player);

  if (players.length >= table.startSlots) {
    gameStart = addSeconds(
      players.length >= table.playerSlots
        ? GAME_START_COUNTDOWN_FULL
        : GAME_START_COUNTDOWN
    );

    publish.event({
      type: "countdown",
      table: table.name,
      players: players,
    });
  }

  if (!player.bot) {
    publish.event({
      type: "join",
      table: table.name,
      player,
    });
  }

  return {
    type: "Join",
    table: { status, turnCount, gameStart },
    players,
    lands,
  };
};

const insertPlayer = (
  players: readonly Player[],
  user: User,
  clientId: any
): [readonly Player[], Player, Player?] => {
  const [heads, tail] = R.splitWhen(isBot, players);
  const newPlayer = makePlayer(user, clientId, heads);
  return [heads.concat([newPlayer]).concat(tail.slice(1)), newPlayer, tail[0]];
};

const takeover = (
  user: User,
  table: Table,
  clientId: string
): CommandResult => {
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (existing) {
    throw new IllegalMoveError("already joined", false);
  }

  if (user.points < table.points) {
    throw new IllegalMoveError("not enough points to join", false);
  }

  if (!table.players.some(isBot) && table.players.length >= table.startSlots) {
    throw new IllegalMoveError("table already full", false);
  }

  if (table.retired.some(retiree => retiree.id === user.id)) {
    throw new IllegalMoveError("cannot join again", false);
  }
  logger.debug(
    table.retired.map(r => r.id),
    user.id
  );

  logger.debug("takeover", typeof user.id);

  const sortedBots = R.sortWith(
    [
      R.descend(
        bot => table.lands.filter(land => land.color === bot.color).length
      ),
      R.descend(bot =>
        R.sum(table.lands.filter(land => land.color).map(l => l.points))
      ),
    ],
    table.players.filter(isBot)
  );

  const bestBot = sortedBots.length >= 2 ? sortedBots[1] : sortedBots[0];

  if (!bestBot) {
    throw new IllegalMoveError("could not find a bot to takeover", false);
  }

  const player = makePlayer(user, clientId, table.players, bestBot.color);
  const players = table.players.map(p => (p === bestBot ? player : p));

  publish.leave(table, bestBot);
  publish.join(table, player);

  publish.event({
    type: "join",
    table: table.name,
    player,
  });

  return {
    type: "Takeover",
    players,
  };
};

export const leave = (
  user: { id: UserId; name: string },
  table: Table
): CommandResult => {
  if (table.status === STATUS_PLAYING) {
    throw new IllegalMoveError("leave while STATUS_PLAYING", false);
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    throw new IllegalMoveError("not joined", false);
  }

  const players = table.players.filter(p => p !== existing);

  const gameStart =
    players.length >= table.startSlots ? addSeconds(GAME_START_COUNTDOWN) : 0;

  const status =
    table.players.length === 0 && table.status === STATUS_PAUSED
      ? STATUS_FINISHED
      : table.status;

  publish.leave(table, existing);
  publish.event({
    type: "join",
    table: table.name,
  });
  return {
    type: "Leave",
    table: { gameStart, status },
    players,
  };
};

export const attack = (
  player: Player,
  table: Table,
  emojiFrom: string,
  emojiTo: string
): CommandResult => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError("attack while not STATUS_PLAYING", player);
  }
  if (!hasTurn(table)(player)) {
    throw new IllegalMoveError("attack while not having turn", player);
  }
  if (table.attack !== null) {
    throw new IllegalMoveError("attack while ongoing attack", player);
  }

  const find = findLand(table.lands);
  const fromLand: Land = find(emojiFrom);
  const toLand = find(emojiTo);
  if (!fromLand || !toLand) {
    logger.debug(table.lands.map(l => l.emoji));
    throw new IllegalMoveError("some land not found in attack", player);
  }
  if (fromLand.color === COLOR_NEUTRAL) {
    throw new IllegalMoveError("attack from neutral", player);
  }
  if (fromLand.points === 1) {
    throw new IllegalMoveError("attack from single-die land", player);
  }
  if (fromLand.color === toLand.color) {
    throw new IllegalMoveError("attack same color", player);
  }
  if (!isBorder(table.adjacency, emojiFrom, emojiTo)) {
    throw new IllegalMoveError("attack not border", player);
  }

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
  };
};

export const endTurn = (
  player: Player,
  table: Table
): [CommandResult, Command | null] => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError("endTurn while not STATUS_PLAYING", player);
  }
  if (!hasTurn(table)(player)) {
    throw new IllegalMoveError("endTurn while not having turn", player);
  }
  if (table.attack !== null) {
    throw new IllegalMoveError("endTurn while ongoing attack", player);
  }

  const existing = table.players.filter(p => p.id === player.id).pop();
  if (!existing) {
    throw new IllegalMoveError("endTurn but did not exist in game", player);
  }

  return nextTurn("EndTurn", table);
};

export const sitOut = (player: Player, table: Table): CommandResult => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError("sitOut while not STATUS_PLAYING", player);
  }

  if (table.players.filter(p => p.id === player.id).length === 0) {
    throw new IllegalMoveError("sitOut while not in game", player);
  }

  //if (hasTurn({ turnIndex: table.turnIndex, players: table.players })(player)) {
  //return nextTurn('SitOut', table, true);
  //}

  return {
    type: "SitOut",
    players: adjustPlayer(
      table.players.indexOf(player),
      { out: true },
      table.players
    ),
  };
};

export const sitIn = (user, table: Table): CommandResult => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError("sitIn while not STATUS_PLAYING", false);
  }
  const player = table.players.filter(p => p.id === user.id).pop();
  if (!player) {
    throw new IllegalMoveError("sitIn while not in game", false);
  }

  const players = table.players.map(p =>
    p === player ? { ...p, out: false, outTurns: 0 } : p
  );
  return { type: "SitIn", players };
};

export const chat = (user: { name: string } | null, table, payload): null => {
  publish.chat(table, user ? user.name : null, payload);
  return null;
};

export const toggleReady = (
  user,
  table: Table,
  payload: boolean
): CommandResult => {
  if (table.status === STATUS_PLAYING) {
    throw new IllegalMoveError("toggleReady while STATUS_PLAYING", user.id);
  }
  const player = table.players.filter(p => p.id === user.id).pop();
  if (!player) {
    throw new IllegalMoveError("toggleReady while not in game", user.id);
  }

  const players = table.players.map(p =>
    p === player ? { ...p, ready: payload } : p
  );
  return { type: "ToggleReady", players };
};

export const flag = (
  player: Player,
  table: Table
): [CommandResult, Command | null] => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError("Flag while not STATUS_PLAYING", player);
  }

  const positions = groupedPlayerPositions(table);
  const position = positions(player);
  if (position === 1) {
    throw new IllegalMoveError("cannot flag first", player);
  }

  if (player.flag !== null && player.flag >= position) {
    throw new IllegalMoveError(
      "cannot flag higher or equal than before",
      player
    );
  }

  logger.debug(`${player.name} flagged ${position}`);

  if (hasTurn(table)(player) && position === table.players.length) {
    logger.debug(`${player.name} flagged suicide`);

    let under: null | { player: Player; points: number } = null;
    let players = table.players;
    if (player.bot && table.players.length === 2) {
      // last bot flags if losing - give kill points to winner
      const remaining = table.players.filter(p => p.id !== player.id);
      const sorted: Player[] = R.sortWith<Player>(
        [R.ascend(positions)],
        remaining
      );
      const penultimate = sorted.pop()!;
      under = {
        player: penultimate,
        points: tablePoints(table) / 2,
      };
      players = players.map(p =>
        p === penultimate
          ? {
              ...penultimate,
              score: penultimate.score + tablePoints(table) / 2,
            }
          : p
      );
    }
    const elimination: Elimination = {
      player,
      position,
      reason: ELIMINATION_REASON_SURRENDER,
      source: {
        flag: position,
        under: under,
      },
    };

    const [players_, lands, turnIndex, eliminations] = removePlayerCascade(
      players,
      table.lands,
      player,
      table.turnIndex,
      elimination
    );

    if (players_.length === table.players.length) {
      throw new Error(`could not remove player ${player.id}`);
    }

    const result: CommandResult = {
      type: "Flag",
      table: { turnStart: now(), turnIndex },
      lands: lands,
      players: players_,
      eliminations,
    };
    if (players_.length === 1) {
      return [
        result,
        { type: "EndGame", winner: players_[0], turnCount: table.turnCount },
      ];
    }
    return [result, null];
  }

  const players = table.players.map(p =>
    p === player ? { ...p, flag: position } : p
  );
  return [{ type: "Flag", players }, null];
};
