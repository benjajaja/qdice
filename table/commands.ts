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
  Color,
  Persona,
  Command,
  IllegalMoveCode,
  Emoji,
  Chatter,
} from "../types";
import * as publish from "./publish";
import { addSeconds, now } from "../timestamp";
import {
  hasTurn,
  findLand,
  adjustPlayer,
  groupedPlayerPositions,
  removePlayerCascade,
  killPoints,
} from "../helpers";
import { isBorder } from "../maps";
import nextTurn from "./turn";
import {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  GAME_START_COUNTDOWN,
  ELIMINATION_REASON_SURRENDER,
  GAME_START_COUNTDOWN_FULL,
} from "../constants";
import logger from "../logger";
import { isBot, tableThemed } from "./bots";
import { addChat } from "./get";

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
    ip: user.ip ?? null,
  };
};

export const join = (
  user: User,
  table: Table,
  clientId: string | null,
  bot: Persona | null
): CommandResult => {
  if (!table.params.tournament && table.status === STATUS_PLAYING) {
    if (clientId !== null && table.players.some(isBot)) {
      return takeover(user, table, clientId);
    }
    throw new IllegalMoveError(
      "join while STATUS_PLAYING",
      IllegalMoveCode.JoinWhilePlaying,
      !!bot
    );
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (existing) {
    throw new IllegalMoveError(
      "already joined",
      IllegalMoveCode.AlreadyJoined,
      !!bot
    );
  }

  if (bot === null && user.points < table.points) {
    throw new IllegalMoveError(
      "not enough points to join",
      IllegalMoveCode.NotEnoughPoints,
      !!bot
    );
  }

  if (!table.players.some(isBot) && table.players.length >= table.playerSlots) {
    throw new IllegalMoveError(
      "table already full",
      IllegalMoveCode.TableFull,
      !!bot
    );
  }

  if (user.ip !== undefined) {
    if (table.players.some(R.propEq("ip", user.ip))) {
      logger.error(
        "User with same ip already in game",
        user.id,
        user.name,
        user.ip
      );
      logger.debug(
        table.players
          .filter(R.propEq("ip", user.ip))
          .map(p => [p.id, p.name, p.ip])
      );
    }
  } else {
    logger.warn("User has no ip:", user.id, user.name);
  }

  let payScores: [UserId, string | null, number][] | undefined = undefined;
  if (table.params.tournament) {
    logger.debug("ips", table.players.map(R.pick(["name", "ip"])));
    const existingIP = table.players
      .filter(p => p.ip && p.ip === user.ip)
      .pop();
    if (existingIP) {
      throw new IllegalMoveError(
        "A player with that IP is already in the game.",
        IllegalMoveCode.DuplicateIP,
        !!bot
      );
    }
    if (table.params.tournament.fee > 0) {
      if (user.points < table.params.tournament.fee) {
        throw new IllegalMoveError(
          "not enough points for game fee",
          IllegalMoveCode.InsufficientFee,
          !!bot
        );
      }
      payScores = [[user.id, clientId, 0 - table.params.tournament.fee]];
      logger.debug("join fee", 0 - table.params.tournament.fee);
    }
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
    const [players, player, removed] = insertPlayer(
      table.players,
      user,
      clientId,
      table.params.tournament?.fee ?? 0
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
      ? table.lands.map(land => ({
          ...land,
          points: 0,
          color: 0,
          capital: false,
        }))
      : table.lands;
  const turnCount = table.status === STATUS_FINISHED ? 1 : table.turnCount;

  let gameStart = table.gameStart;

  publish.join(table, player);

  if (!table.params.tournament && players.length >= table.startSlots) {
    gameStart = addSeconds(
      players.length >= table.playerSlots
        ? GAME_START_COUNTDOWN_FULL
        : GAME_START_COUNTDOWN
    );
  }

  return {
    table: { status, turnCount, gameStart },
    players,
    lands,
    payScores,
  };
};

const insertPlayer = (
  players: readonly Player[],
  user: User,
  clientId: any,
  fee: number
): [readonly Player[], Player, Player?] => {
  const [heads, tail] = R.splitWhen(isBot, players);
  const newPlayer = {
    ...makePlayer(user, clientId, heads),
    points: user.points - fee,
  };
  return [heads.concat([newPlayer]).concat(tail.slice(1)), newPlayer, tail[0]];
};

const takeover = (
  user: User,
  table: Table,
  clientId: string
): CommandResult => {
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (existing) {
    throw new IllegalMoveError(
      "already joined",
      IllegalMoveCode.AlreadyJoined,
      false
    );
  }

  if (user.points < table.points) {
    throw new IllegalMoveError(
      "not enough points to join",
      IllegalMoveCode.NotEnoughPoints,
      false
    );
  }

  if (!table.players.some(isBot) && table.players.length >= table.startSlots) {
    throw new IllegalMoveError(
      "table already full",
      IllegalMoveCode.TableFull,
      false
    );
  }

  if (table.retired.some(retiree => retiree.id === user.id)) {
    throw new IllegalMoveError(
      "cannot join again",
      IllegalMoveCode.IsRetired,
      false
    );
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
      R.descend(_ =>
        R.sum(table.lands.filter(land => land.color).map(l => l.points))
      ),
    ],
    table.players.filter(isBot)
  );

  const bestBot = sortedBots.length >= 2 ? sortedBots[1] : sortedBots[0];

  if (!bestBot) {
    throw new IllegalMoveError(
      "could not find a bot to takeover",
      IllegalMoveCode.NoTakeoverTargets,
      false
    );
  }

  const player = makePlayer(user, clientId, table.players, bestBot.color);
  const players = table.players.map(p => (p === bestBot ? player : p));

  publish.leave(table, bestBot);
  publish.join(table, player);

  return {
    players,
  };
};

export const leave = (
  user: { id: UserId; name: string },
  table: Table
): CommandResult => {
  if (table.status === STATUS_PLAYING) {
    throw new IllegalMoveError(
      "leave while STATUS_PLAYING",
      IllegalMoveCode.LeaveWhilePlaying,
      false
    );
  }

  if (table.params.tournament) {
    throw new IllegalMoveError(
      "cannot leave tournament",
      IllegalMoveCode.LeaveTournament,
      false
    );
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    throw new IllegalMoveError("not joined", IllegalMoveCode.NotJoined, false);
  }

  const players = table.players.filter(p => p !== existing);

  const gameStart = !table.params.tournament
    ? players.length >= table.startSlots && !players.every(isBot)
      ? addSeconds(GAME_START_COUNTDOWN)
      : 0
    : table.gameStart;

  const status =
    table.players.length === 0 && table.status === STATUS_PAUSED
      ? STATUS_FINISHED
      : table.status;

  publish.leave(table, existing);
  return {
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
    throw new IllegalMoveError(
      "attack while not STATUS_PLAYING",
      IllegalMoveCode.AttackWhileStopped,
      player
    );
  }
  if (!hasTurn(table)(player)) {
    throw new IllegalMoveError(
      "attack while not having turn",
      IllegalMoveCode.AttackOutOfTurn,
      player
    );
  }
  if (table.attack !== null) {
    throw new IllegalMoveError(
      "attack while ongoing attack",
      IllegalMoveCode.AttackWhileAttack,
      player
    );
  }

  const find = findLand(table.lands);
  const fromLand: Land = find(emojiFrom);
  const toLand = find(emojiTo);
  if (!fromLand || !toLand) {
    logger.debug(table.lands.map(l => l.emoji));
    throw new IllegalMoveError(
      "some land not found in attack",
      IllegalMoveCode.AttackLandsNotFound,
      player
    );
  }
  if (fromLand.color < 1) {
    // TODO === Color.Neutral
    throw new IllegalMoveError(
      "attack from neutral",
      IllegalMoveCode.AttackFromNeutral,
      player
    );
  }
  if (fromLand.points === 1) {
    throw new IllegalMoveError(
      "attack from single-die land",
      IllegalMoveCode.AttackFromOnePoint,
      player
    );
  }
  if (fromLand.color === toLand.color) {
    throw new IllegalMoveError(
      "attack same color",
      IllegalMoveCode.AttackSameColor,
      player
    );
  }
  if (!isBorder(table.adjacency, emojiFrom, emojiTo)) {
    throw new IllegalMoveError(
      "attack not border",
      IllegalMoveCode.AttackNotBorder,
      player
    );
  }

  const timestamp = now();
  publish.move(table, {
    from: emojiFrom,
    to: emojiTo,
  });
  return {
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
  player: Player | null,
  table: Table,
  sitPlayerOut: boolean,
  dice: {
    lands: readonly [Emoji, number][];
    reserve: number;
    capitals: readonly Emoji[];
  }
): [CommandResult, Command | null] => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError(
      "endTurn while not STATUS_PLAYING",
      IllegalMoveCode.EndTurnWhileStopped,
      player ?? undefined
    );
  }
  if (player && !hasTurn(table)(player)) {
    throw new IllegalMoveError(
      "endTurn while not having turn",
      IllegalMoveCode.EndTurnOutOfTurn,
      player
    );
  }
  if (table.attack !== null) {
    throw new IllegalMoveError(
      "endTurn while ongoing attack",
      IllegalMoveCode.EndTurnDuringAttack,
      player ?? undefined
    );
  }

  if (player) {
    const existing = table.players.filter(p => p.id === player.id).pop();
    if (!existing) {
      throw new IllegalMoveError(
        "endTurn but did not exist in game",
        IllegalMoveCode.EndTurnNoPlayer,
        player
      );
    }
  }

  return nextTurn(table, sitPlayerOut, dice);
};

export const sitOut = (player: Player, table: Table): CommandResult => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError(
      "sitOut while not STATUS_PLAYING",
      IllegalMoveCode.SitOutNotPlaying,
      player
    );
  }

  if (table.players.filter(p => p.id === player.id).length === 0) {
    throw new IllegalMoveError(
      "sitOut while not in game",
      IllegalMoveCode.SitOutNoPlayer,
      player
    );
  }

  //if (hasTurn({ turnIndex: table.turnIndex, players: table.players })(player)) {
  //return nextTurn('SitOut', table, true);
  //}

  publish.playerStatus(table, { ...player, out: true });
  return {
    players: adjustPlayer(
      table.players.indexOf(player),
      { out: true },
      table.players
    ),
  };
};

export const sitIn = (user: Player, table: Table): CommandResult => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError(
      "sitIn while not STATUS_PLAYING",
      IllegalMoveCode.SitOutNotPlaying,
      false
    );
  }
  const player = table.players.filter(p => p.id === user.id).pop();
  if (!player) {
    throw new IllegalMoveError(
      "sitIn while not in game",
      IllegalMoveCode.SitInNoPlayerfalse
    );
  }

  const players = table.players.map(p =>
    p === player ? { ...p, out: false, outTurns: 0 } : p
  );
  publish.playerStatus(table, { ...player, out: false });
  return { players };
};

export const chat = (user: Chatter, table: Table, payload: string): null => {
  publish.chat(table, user, payload);
  addChat(table, user, payload);
  return null;
};

export const toggleReady = (
  user: Player,
  table: Table,
  payload: boolean
): [CommandResult, Command | null] => {
  if (table.status === STATUS_PLAYING) {
    throw new IllegalMoveError(
      "toggleReady while STATUS_PLAYING",
      IllegalMoveCode.IllegalReady,
      false
    );
  }
  const player = table.players.filter(p => p.id === user.id).pop();
  if (!player) {
    throw new IllegalMoveError(
      "toggleReady while not in game",
      IllegalMoveCode.ReadyWhilePlaying,
      false
    );
  }

  const players = table.players.map(p =>
    p === player ? { ...p, ready: payload } : p
  );
  if (
    table.params.readySlots !== null &&
    players.length >= table.params.readySlots &&
    players.every(p => p.ready)
  ) {
    return [{ players }, { type: "Start", players }];
  }
  return [{ players }, null];
};

export const flag = (
  player: Player,
  clientPosition: number,
  table: Table
): [CommandResult, Command | null] => {
  if (table.status !== STATUS_PLAYING) {
    throw new IllegalMoveError(
      "Flag while not STATUS_PLAYING",
      IllegalMoveCode.FlagWhileNotPlaying,
      player
    );
  }

  const positions = groupedPlayerPositions(table);
  const position = positions(player);
  if (position === 1) {
    throw new IllegalMoveError(
      "cannot flag first",
      IllegalMoveCode.FlagFirst,
      player
    );
  }
  if (position !== clientPosition) {
    throw new IllegalMoveError(
      `client flagged ${clientPosition} but server is ${position}`,
      IllegalMoveCode.FlagMismatch,
      player
    );
  }

  if (player.flag !== null && player.flag >= position) {
    throw new IllegalMoveError(
      "cannot flag higher or equal than before",
      IllegalMoveCode.FlagUp,
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
        points: killPoints(table),
      };
      players = players.map(p =>
        p === penultimate
          ? {
              ...penultimate,
              score: penultimate.score + killPoints(table),
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
      elimination,
      killPoints(table)
    );

    if (players_.length === table.players.length) {
      throw new Error(`could not remove player ${player.id}`);
    }

    const result: CommandResult = {
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
  publish.playerStatus(table, { ...player, flag: position });
  return [{ players }, null];
};
