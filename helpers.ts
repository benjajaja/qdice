import * as R from 'ramda';
import { Table, Land, UserLike, Player } from './types';

export const findTable = (tables: Table[]) => (name: string): Table => tables.filter(table => table.name === name).pop()!;

export const findLand = (lands: ReadonlyArray<Land>) => (emoji: string): Land => lands.filter(land => land.emoji === emoji).pop()!;

export const hasTurn = (table: Table) => (playerLike: UserLike): boolean =>
  table.players.indexOf(
    table.players.filter(p => p.id === playerLike.id).pop()!
  ) === table.turnIndex;

const scoreStep = 10;
export const positionScore = multiplier => gameSize => position => {
  const invPos = gameSize - position + 1;
  return R.pipe(
    factor => factor * multiplier / scoreStep / gameSize,
    Math.round,
    R.multiply(scoreStep),
    R.defaultTo(0),
  )(
      ((invPos * (invPos / gameSize)) - (gameSize / 2)) * 2
  );
};

export const groupedPlayerPositions = table => {
  const positions = (R.pipe as any)(
    R.map((player: Player) => [
      player.id,
      table.lands.filter(R.propEq('color', player.color)).length,
    ]),
    R.sortBy(R.nth(1) as any),
    R.reverse,
  )(table.players)
  .map(([id, count], i) => [id, count, i + 1])
  .reduce((acc, [id, landCount, position], i) => {
    return R.append(i > 0 && acc[i - 1][1] === landCount
      ? [id, landCount, acc[i - 1][2]]
      : [id, landCount, position])(acc);
  }, []);
  
  return player => R.find(R.propEq(0, player.id), positions)[2];
};


export const tablePoints = (table: Table): number =>
  table.points === 0
    ? 50
    : table.points;

