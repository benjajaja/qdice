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

  const currentPlayer = inPlayers[table.turnIndex];
  const [receivedDice, lands, players, hasReserveDice] = currentPlayer
    ? giveDice(table, table.lands, inPlayers)(currentPlayer) // not just removed
    : [0, table.lands, table.players, false];

  if (receivedDice > 0) {
    publish.receivedDice(table, receivedDice, currentPlayer, lands, players);
  }

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
    position === table.players.length
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
      table.players,
      table.lands,
      newPlayer,
      props.turnIndex,
      elimination
    );

    if (players_.length === players.length) {
      throw new Error(`could not remove player ${newPlayer.id}`);
    }
    props.turnIndex = turnIndex;
    // props.turnIndex =
    // props.turnIndex + 1 < players_.length ? props.turnIndex + 1 : 0;

    const { newCapitals, newLands } = giveCapitals(
      table,
      hasReserveDice,
      players_,
      lands_
    );
    const result = {
      table: props,
      lands: newLands,
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
        players_,
        newCapitals
      );
      return [result, null];
    }
  }

  if (!newPlayer.out) {
    // normal turn over
    const { newCapitals, newLands } = giveCapitals(
      table,
      hasReserveDice,
      players,
      lands
    );
    publish.turn(
      table,
      props.turnIndex,
      props.turnStart,
      props.roundCount,
      players,
      newCapitals
    );
    return [{ table: props, lands: newLands, players }, null];
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
      table.players,
      table.lands,
      newPlayer,
      props.turnIndex,
      elimination
    );
    props.turnIndex = turnIndex;

    const { newCapitals, newLands } = giveCapitals(
      table,
      hasReserveDice,
      players_,
      lands_
    );
    const result = {
      table: props,
      lands: newLands,
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
        players_,
        newCapitals
      );
      return [result, null];
    }
  }

  const { newCapitals, newLands } = giveCapitals(
    table,
    hasReserveDice,
    players,
    lands
  );
  publish.turn(
    table,
    props.turnIndex,
    props.turnStart,
    props.roundCount,
    players,
    newCapitals
  );
  return [
    {
      table: props,
      lands: newLands,
      players: players.map(player => {
        if (player === newPlayer) {
          return { ...player, outTurns: player.outTurns + 1 };
        }
        return player;
      }),
    },
    null,
  ];
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
  hasReserveDice: boolean,
  players: readonly Player[],
  lands: readonly Land[]
): { newLands: readonly Land[]; newCapitals: readonly Land[] } => {
  // logger.debug(
  // `giveCapitals: params:${
  // table.params.startingCapitals
  // }, reserve:${hasReserveDice}, previousCapitals:${lands.some(
  // land => land.capital
  // )}`
  // );
  if (
    table.params.startingCapitals ||
    hasReserveDice ||
    lands.some(land => land.capital)
  ) {
    return players.reduce(
      (result, { color }) => {
        const playerLands = result.newLands.filter(R.propEq("color", color));
        if (playerLands.every(R.propEq("capital", false))) {
          logger.debug(`giving new capital to #${color}`);
          const match = R.sortWith(
            [R.ascend(R.prop("points"))],
            shuffle(playerLands)
          ).pop();
          if (match) {
            const newCapital = { ...match, capital: true };
            return {
              newLands: result.newLands.map(l =>
                l.emoji === newCapital.emoji ? newCapital : l
              ),
              newCapitals: [...result.newCapitals, newCapital],
            };
          } else {
            logger.error(`#${color} has no capital but I can't find it again!`);
          }
        }
        return result;
      },
      { newLands: lands, newCapitals: [] }
    );
  }
  return { newLands: lands, newCapitals: [] };
};

export default turn;
