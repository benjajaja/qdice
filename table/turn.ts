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
  sitPlayerOut = false
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
  const [receivedDice, lands, players, hasReserveDice] = giveDice(
    table,
    table.lands,
    inPlayers
  )(currentPlayer); // not just removed

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
      lands: giveCapitals(table, players_, lands_),
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
    const lands_ = giveCapitals(table, players, lands);
    publish.turn(
      table,
      props.turnIndex,
      props.turnStart,
      props.roundCount,
      [currentPlayer, receivedDice],
      players,
      lands_
    );
    return [{ table: props, lands: lands_, players }, null];
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
      lands: giveCapitals(table, players_, lands_),
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
    lands: giveCapitals(table, players_, lands),
    players: players_,
  };
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
};

const giveDice = (
  table: Table,
  lands: ReadonlyArray<Land>,
  players: ReadonlyArray<Player>
) => (
  player: Player
): [number, ReadonlyArray<Land>, ReadonlyArray<Player>, boolean] => {
  const connectLandCount = maps.countConnectedLands({
    lands,
    adjacency: table.adjacency,
  })(player.color);
  const newDies = connectLandCount + player.reserveDice;

  let reserveDice = 0;

  R.range(0, newDies).forEach(i => {
    const targets = lands.filter(
      land => land.color === player.color && land.points < table.stackSize
    );
    if (targets.length === 0) {
      reserveDice += 1;
    } else {
      let target: Land;
      if (i >= connectLandCount) {
        target =
          targets.find(R.propEq("capital", true)) ??
          targets[rand(0, targets.length - 1)];
      } else {
        target = targets[rand(0, targets.length - 1)];
      }
      lands = updateLand(lands, target, { points: target.points + 1 });
    }
  });
  return [
    connectLandCount,
    lands,
    players.map(p => (p === player ? { ...player, reserveDice } : p)),
    reserveDice > 0,
  ];
};

const giveCapitals = (
  table: Table,
  players: readonly Player[],
  lands: readonly Land[]
): readonly Land[] => {
  if (table.params.startingCapitals) {
    return players.reduce((result: Land[], { color }) => {
      const playerLands = result.filter(R.propEq("color", color));
      if (playerLands.every(R.propEq("capital", false))) {
        logger.debug(`giving new capital to #${color}`);
        const match = R.sortWith(
          [R.ascend(R.prop("points"))],
          shuffle(playerLands)
        ).pop();
        if (match) {
          const newCapital = { ...match, capital: true };
          return result.map(l =>
            l.emoji === newCapital.emoji ? newCapital : l
          );
        } else {
          logger.error(`#${color} has no capital but I can't find it again!`);
        }
      }
      return result;
    }, lands);
  }
  return lands;
};

export default turn;
