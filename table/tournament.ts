import { Table, Command, TableParams, TournamentParam } from "../types";
import { STATUS_PLAYING } from "../constants";
import { nextFrequency, now } from "../timestamp";
import { countdownFinished } from "./tick";

export const tickTournament = (
  table: Table,
  tournament: TournamentParam
): Command | void => {
  if (table.status !== STATUS_PLAYING) {
    if (table.gameStart === 0) {
      const [gameStart, map] = nextFrequency(tournament.frequency, now(), table.mapName);
      return { type: "SetGameStart", gameStart, map, returnFee: null };
    } else if (countdownFinished(table.gameStart)) {
      const [gameStart, map] = nextFrequency(tournament.frequency, now(), table.mapName);
      return { type: "SetGameStart", gameStart, map, returnFee: tournament.fee };
    } else if (table.gameStart > nextFrequency(tournament.frequency, now(), table.mapName)[0]) {
      const [gameStart, map] = nextFrequency(tournament.frequency, now(), table.mapName);
      return { type: "SetGameStart", gameStart, map, returnFee: null };
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
