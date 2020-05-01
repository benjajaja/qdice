import { Timestamp, TournamentFrequency } from "./types";
import { assertNever } from "./helpers";
import { shuffle } from "./rand";
import logger from "./logger";

export const ts = (date: Date): Timestamp => {
  return date.getTime();
};

export const now = (): Timestamp => {
  return ts(new Date());
};

export const addSeconds = (seconds: number, timestamp: Timestamp = now()) => {
  return timestamp + seconds * 1000;
};

export const date = (timestamp: Timestamp): Date => {
  return new Date(timestamp);
};

export const seconds = (from: Timestamp, to: Timestamp = now()): number => {
  return to - from;
};

export const havePassed = (
  seconds: number,
  from: Timestamp,
  to: Timestamp = now()
): boolean => {
  return to - from >= seconds * 1000;
};

export const nextFrequency = (
  frequency: TournamentFrequency,
  ts: Timestamp,
  currentMap: string,
): [Timestamp, string | null] => {
  const d = date(ts);
  switch (frequency) {
    case "minutely":
      const seconds = 60 - d.getSeconds();
      return [ts + 1000 * seconds, nextMap(currentMap)];
    case "5minutely":
      const minutes5 = 5 - (d.getMinutes() % 5);
      return [ts + 1000 * 60 * minutes5, nextMap(currentMap)];
    case "hourly":
      const minutes = 60 - d.getMinutes();
      return [ts + 1000 * 60 * minutes, nextMap(currentMap)];
    case "daily":
      const hours = 18 - d.getHours();
      return [(
        ts +
        1000 * 60 * 60 * (hours > 0 ? hours : hours + 18) -
        1000 * 60 * d.getMinutes() -
        1000 * d.getSeconds()
      ), nextMap(currentMap)];
    case "weekly":
      return [ts + 1000 * 60 * 60 * 24 * 7, nextMap(currentMap)];
    case "monthly":
      return [ts + 1000 * 60 * 60 * 24 * 30, nextMap(currentMap)];
    default:
      return assertNever(frequency);
  }
};

const mapCycle = ["Planeta", "Montoya", "DeLucía", "Sabicas", "Cepero"];
const nextMap = (map: string) => {
  return shuffle(mapCycle)[0];
};
