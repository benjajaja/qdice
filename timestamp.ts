import { Timestamp } from "./types";

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
