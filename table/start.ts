import * as R from "ramda";
import { Table, Player, Land, CommandResult, Color } from "../types";
import { now } from "../timestamp";
import * as publish from "./publish";
import { rand, shuffle } from "../rand";
import logger from "../logger";
import { STATUS_PLAYING } from "../constants";

const randomPoints = stackSize => {
  const r = rand(0, 999) / 1000;
  if (r > 0.98) return Math.min(8, Math.floor(stackSize / 2 + 1));
  else if (r > 0.9) return Math.floor(stackSize / 2);
  return rand(1, Math.floor(stackSize / 4));
};

const start = (table: Table): CommandResult => {
  const lands = R.sort<Land>((a, b) => a.emoji.localeCompare(b.emoji))(
    table.lands
  ).map(land =>
    Object.assign({}, land, {
      points: randomPoints(table.stackSize),
      color: -1,
    })
  );

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

  const specialAssignedLands: Land[] =
    table.name !== "Planeta"
      ? assignedLands
      : (() => {
          const wuhan = assignedLands.find(R.propEq("emoji", "💊"));
          if (wuhan) {
            const covidLand = assignedLands.find(
              R.propEq("color", Color.Black)
            );

            return assignedLands.map(land => {
              if (land === wuhan) {
                return { ...land, color: Color.Black, points: 5 };
              } else if (land === covidLand && wuhan.color !== Color.Neutral) {
                return { ...land, color: wuhan.color };
              }
              return land;
            });
          } else {
            return assignedLands
              .filter(land => land.color !== Color.Black)
              .concat(
                lands
                  .filter(land => land.emoji === "💊")
                  .map(land => ({ ...land, color: Color.Black, points: 5 }))
              );
          }
        })();

  const allLands = lands.map(oldLand => {
    const match = specialAssignedLands
      .filter(l => l.emoji === oldLand.emoji)
      .pop();
    if (match) {
      return match;
    }
    return oldLand;
  });

  return {
    type: "TickStart",
    table: {
      status: STATUS_PLAYING,
      gameStart: now(),
      turnIndex: 0,
      turnStart: now(),
      turnActivity: false,
      playerStartCount: table.players.length,
      roundCount: 1,
    },
    lands: allLands,
  };
};
export default start;
