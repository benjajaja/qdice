import * as R from 'ramda';

export const rand = (min, max) => Math.floor(Math.random() * (max + 1 - min)) + min;

export const diceRoll = (fromPoints, toPoints) => {
  const fromRoll = R.range(0, fromPoints).map(_ => rand(1, 6));
  const toRoll = R.range(0, toPoints).map(_ => rand(1, 6));
  const success = R.sum(fromRoll) > R.sum(toRoll);
  return [fromRoll, toRoll, success];
};

