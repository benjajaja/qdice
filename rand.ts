import * as R from "ramda";
import * as seedrandom from "seedrandom";
import logger from "./logger";

export const resetGenerator = () => {
  generator = seedrandom(process.env.E2E ? "some value" : undefined);
  logger.info(`first rand value: ${generator()}`);
  return generator;
};

let generator: ReturnType<typeof seedrandom> = resetGenerator();

export const rand = (min: number, max: number) =>
  Math.floor(generator() * (max + 1 - min)) + min;

export const diceRoll = (fromPoints: number, toPoints: number) => {
  const fromRoll = R.range(0, fromPoints).map(_ => rand(1, 6));
  const toRoll = R.range(0, toPoints).map(_ => rand(1, 6));
  const success = R.sum(fromRoll) > R.sum(toRoll);
  return [fromRoll, toRoll, success];
};

/**
 * It mutates and returns the input
 */
export const shuffle = <T>(a: T[]): ReadonlyArray<T> => {
  for (let i = a.length - 1; i > 0; i--) {
    const j = rand(0, i);
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
};
