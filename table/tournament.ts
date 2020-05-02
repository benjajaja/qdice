import { Table, Command, TournamentParam } from "../types";
import { STATUS_PLAYING } from "../constants";
import { nextFrequency, now } from "../timestamp";
import { countdownFinished } from "./tick";
import { nextMap } from "../maps";
import logger from "../logger";

export const tickTournament = (
  table: Table,
  tournament: TournamentParam
): Command | void => {
  if (table.status !== STATUS_PLAYING) {
    if (table.gameStart === 0) {
      const gameStart = nextFrequency(tournament.frequency, now());
      return {
        type: "SetGameStart",
        gameStart,
        map: nextMap(table.mapName),
        returnFee: null,
      };
    } else if (countdownFinished(table.gameStart)) {
      const gameStart = nextFrequency(tournament.frequency, now());
      return {
        type: "SetGameStart",
        gameStart,
        map: nextMap(table.mapName),
        returnFee: tournament.fee,
      };
    } else if (
      table.gameStart >
      nextFrequency(tournament.frequency, now()) + 10000
    ) {
      logger.debug("tournament is future");
      const gameStart = nextFrequency(tournament.frequency, now());
      return { type: "SetGameStart", gameStart, map: null, returnFee: null };
    }
  }
  return undefined;
};

export const tournamentScore = (table: Table, position: number) => {
  if (!table.params.tournament) {
    return 0;
  }
  if (position === 1) {
    return table.params.tournament.prize;
  }
  return 0;
};
