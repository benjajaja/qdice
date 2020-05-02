import { Timestamp, TournamentFrequency } from "./types";
import { assertNever } from "./helpers";

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
  ts: Timestamp
): Timestamp => {
  const d = date(ts);
  switch (frequency) {
    case "minutely":
      const seconds = 60 - d.getSeconds();
      return ts + 1000 * seconds;
    case "5minutely":
      const minutes5 = 5 - (d.getMinutes() % 5);
      return ts + 1000 * 60 * minutes5;
    case "hourly":
      const minutes = 60 - d.getMinutes();
      return ts + 1000 * 60 * minutes;
    case "daily":
      const hours = 18 - d.getHours();
      return (
        ts +
        1000 * 60 * 60 * (hours > 0 ? hours : hours + 18) -
        1000 * 60 * d.getMinutes() -
        1000 * d.getSeconds()
      );
    case "weekly":
      return ts + 1000 * 60 * 60 * 24 * 7;
    case "monthly":
      return ts + 1000 * 60 * 60 * 24 * 30;
    default:
      return assertNever(frequency);
  }
};
