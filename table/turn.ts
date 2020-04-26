import * as R from "ramda";
import * as maps from "../maps";
import { rand, shuffle } from "../rand";
import logger from "../logger";
import {
  Table,
  Land,
  Player,
  CommandResult,
  Command,
  Elimination,
  Emoji,
} from "../types";
import {
  updateLand,
  groupedPlayerPositions,
  removePlayerCascade,
  killPoints,
} from "../helpers";
import * as publish from "./publish";

import {
  ELIMINATION_REASON_OUT,
  ELIMINATION_REASON_SURRENDER,
  OUT_TURN_COUNT_ELIMINATION,
} from "../constants";
import { now } from "../timestamp";

const turn = (
  table: Table,
  sitPlayerOut = false,
  dice: {
    lands: readonly [Emoji, number][];
    reserve: number;
    capitals: readonly Emoji[];
  }
): [CommandResult, Command | null] => {
  const inPlayers = sitPlayerOut
    ? R.adjust(
        player => ({ ...player, out: true }),
        table.turnIndex,
        table.players
      )
    : table.players;

  const currentPlayer: Player = inPlayers[table.turnIndex];
  if (!currentPlayer) {
    throw new Error(
      "turn without current player by index: " +
        table.turnIndex +
        " of (" +
        inPlayers.length +
        ")"
    );
  }
  const [receivedDice, lands, players] = applyDice(
    table,
    inPlayers,
    currentPlayer,
    dice
  );

  const nextIndex =
    table.turnIndex + 1 < players.length ? table.turnIndex + 1 : 0;

  const props = {
    turnIndex: nextIndex,
    turnStart: now(),
    turnActivity: false,
    turnCount: table.turnCount + 1,
    roundCount: nextIndex === 0 ? table.roundCount + 1 : table.roundCount,
  };

  const newPlayer = players[props.turnIndex];

  const positions = groupedPlayerPositions(table);
  const position = positions(newPlayer);

  // next player flagged and surrenders
  if (
    newPlayer.flag !== null &&
    newPlayer.flag >= position &&
    position === players.length
  ) {
    const elimination: Elimination = {
      player: newPlayer,
      position: players.length,
      reason: ELIMINATION_REASON_SURRENDER,
      source: {
        flag: newPlayer.flag,
        under: null,
      },
    };
    const [players_, lands_, turnIndex, eliminations] = removePlayerCascade(
      players,
      lands,
      newPlayer,
      props.turnIndex,
      elimination,
      killPoints(table)
    );

    if (players_.length === players.length) {
      throw new Error(`could not remove player ${newPlayer.id}`);
    }
    props.turnIndex = turnIndex;
    // props.turnIndex =
    // props.turnIndex + 1 < players_.length ? props.turnIndex + 1 : 0;

    const result = {
      table: props,
      lands: lands_,
      players: players_,
      eliminations,
    };

    if (players_.length === 1) {
      // okthxbye
      return [
        result,
        { type: "EndGame", winner: players_[0], turnCount: table.turnCount },
      ];
    }
    publish.turn(
      table,
      props.turnIndex,
      props.turnStart,
      props.roundCount,
      [currentPlayer, receivedDice],
      players_,
      result.lands
    );
    return [result, null];
  }

  if (!newPlayer.out) {
    // normal turn over
    publish.turn(
      table,
      props.turnIndex,
      props.turnStart,
      props.roundCount,
      [currentPlayer, receivedDice],
      players,
      lands
    );
    return [{ table: props, lands: lands, players }, null];
  }

  if (newPlayer.outTurns > OUT_TURN_COUNT_ELIMINATION) {
    const elimination = {
      player: newPlayer,
      position: players.length,
      reason: ELIMINATION_REASON_OUT,
      source: {
        turns: newPlayer.outTurns,
      },
    };
    const [players_, lands_, turnIndex, eliminations] = removePlayerCascade(
      players,
      lands,
      newPlayer,
      props.turnIndex,
      elimination,
      killPoints(table)
    );
    props.turnIndex = turnIndex;

    const result = {
      table: props,
      lands: lands_,
      players: players_,
      eliminations,
    };

    if (players_.length === 1) {
      // okthxbye
      return [
        result,
        { type: "EndGame", winner: players_[0], turnCount: table.turnCount },
      ];
    } else {
      publish.turn(
        table,
        props.turnIndex,
        props.turnStart,
        props.roundCount,
        [currentPlayer, receivedDice],
        players_,
        result.lands
      );
      return [result, null];
    }
  }

  const players_ = players.map(player => {
    if (player === newPlayer) {
      return { ...player, outTurns: player.outTurns + 1 };
    }
    return player;
  });

  const result = {
    table: props,
    lands,
    players: players_,
  };
  publish.turn(
    table,
    props.turnIndex,
    props.turnStart,
    props.roundCount,
    [currentPlayer, receivedDice],
    players_,
    lands
  );
  return [result, null];
};

const applyDice = (
  table: Table,
  players: readonly Player[],
  player: Player,
  dice: {
    lands: readonly [Emoji, number][];
    reserve: number;
    capitals: readonly Emoji[];
  }
): [number, readonly Land[], readonly Player[]] => {
  const count = R.sum(dice.lands.map(([_, count]) => count)) + dice.reserve;

  const players_ = players.map(p =>
    p.id === player.id ? { ...p, reserveDice: p.reserveDice + dice.reserve } : p
  );
  const lands = table.lands
    .map(land =>
      dice.lands.reduce((land, [emoji, count]) => {
        if (land.emoji === emoji) {
          return { ...land, points: land.points + count };
        }
        return land;
      }, land)
    )
    .map(land => {
      if (dice.capitals.indexOf(land.emoji) !== -1) {
        return { ...land, capital: true };
      }
      return land;
    });

  if (lands.some(land => land.points > 8)) {
    throw new Error("applyDice applied too much dice!");
  }

  return [count, lands, players_];
};

export default turn;
