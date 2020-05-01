import * as R from "ramda";
import * as publish from "./publish";
import { Table, Land, CommandResult, Color, User, UserId } from "../types";
import { now } from "../timestamp";
import { rand, shuffle } from "../rand";
import logger from "../logger";
import { STATUS_PLAYING } from "../constants";

const randomPoints = (stackSize: number) => {
  const r = rand(0, 999) / 1000;
  if (r > 0.98) return Math.min(8, Math.floor(stackSize / 2 + 1));
  else if (r > 0.9) return Math.floor(stackSize / 2);
  return rand(1, Math.floor(stackSize / 4));
};

export const startGame = (table: Table): CommandResult => {
  const lands = R.sort<Land>((a, b) => a.emoji.localeCompare(b.emoji))(
    table.lands
  ).map(land =>
    Object.assign({}, land, {
      points: randomPoints(table.stackSize),
      color: 0,
    })
  );

  const assignedLands = assignLands(table, lands).map(
    table.params.startingCapitals
      ? land => ({ ...land, capital: land.color !== Color.Neutral })
      : land => ({ ...land, capital: false })
  );

  const allLands = lands.map(oldLand => {
    const match = assignedLands.filter(l => l.emoji === oldLand.emoji).pop();
    if (match) {
      return match;
    }
    return oldLand;
  });

  const props = {
    status: STATUS_PLAYING,
    gameStart: now(),
    turnIndex: 0,
    turnStart: now(),
    turnActivity: false,
    playerStartCount: table.players.length,
    roundCount: 1,
  };
  publish.turn(
    table,
    props.turnIndex,
    props.turnStart,
    props.roundCount,
    null,
    table.players,
    allLands
  );
  return {
    table: props,
    lands: allLands,
  };
};

const assignLands = (table: Table, lands: readonly Land[]): readonly Land[] => {
  const spread = loadSpread(table.mapName, table.players.length);
  if (spread !== null) {
    logger.debug("attempting to use pregenerated spread");
    const newLands = lands.map(land => {
      const index = spread.indexOf(land.emoji);
      if (index !== -1) {
        return { ...land, color: index + 1, points: 4 };
      }
      return land;
    });

    if (
      R.range(1, table.players.length).every(i =>
        newLands.find(R.propEq("color", i))
      )
    ) {
      logger.info(
        `Loaded pregenerated spread for ${table.mapName} with ${table.players.length}`
      );
      return newLands;
    }
    logger.error("did not allocate correctly");
  }

  const shuffledLands = shuffle(lands.slice())
    .slice(0, table.players.length)
    .map(land =>
      Object.assign({}, land, {
        points: randomPoints(table.stackSize),
      })
    );

  const assignedLands: Land[] = shuffledLands.map((land, index) => {
    const player = table.players[index % table.players.length];
    return Object.assign({}, land, { color: player.color, points: 4 });
  });
  return assignedLands;
};

let preloadedStartingPositions: {
  [table: string]: {
    [size: number]: readonly (readonly string[])[];
  };
} = {};
const loadSpread = (
  mapName: string,
  size: number
): readonly string[] | null => {
  const positions = preloadedStartingPositions[mapName]?.[size];
  if (!positions) {
    logger.error(
      `starting positions have not been preloaded for ${mapName} / ${size}`
    );
    return null;
  } else {
    try {
      const emojis = positions[rand(0, positions.length - 1)];
      return shuffle(emojis);
    } catch (e) {
      logger.error(
        `starting positions are not appropiate for ${mapName} / ${size}`
      );
      return null;
    }
  }
};

export const preloadStartingPositions = async (
  mapName: string
): Promise<void> => {
  const sizesList: { [size: number]: string[][] } = {};
  for (let p = 2; p <= 8; p++) {
    for (let i = 4; i > 0; i--) {
      try {
        const json: string[][] = require(`../starting_positions/maps/output/${mapName}_${i}_sep_${p}_players.json`);
        logger.debug(`got starting positions for ${mapName} (${p} players)`);
        sizesList[p] = json;
        break;
      } catch (e) {}
    }
  }
  preloadedStartingPositions[mapName] = sizesList;
};

export const setGameStart = (
  table: Table,
  gameStart: number,
  returnFee: number | null
): CommandResult => {
  if (returnFee === null || returnFee === 0) {
    return {
      table: { gameStart },
      players: [],
    };
  }

  const payScores: [UserId, string | null, number][] = table.players.map(
    player => {
      return [player.id, player.clientId, returnFee];
    }
  );
  return {
    table: { gameStart },
    players: [],
    payScores: payScores,
  };
};
