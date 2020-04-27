import { Table, Command, TableParams, TournamentParam } from "../types";
import { STATUS_PLAYING } from "../constants";
import { nextFrequency, now } from "../timestamp";
import { countdownFinished } from "./tick";

export const tickTournament = (
  table: Table,
  tournament: TournamentParam
): Command | void => {
  if (table.status !== STATUS_PLAYING) {
    if (table.gameStart === 0 || countdownFinished(table.gameStart)) {
      const gameStart = nextFrequency(tournament.frequency, now());
      return { type: "SetGameStart", gameStart };
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
