import * as R from 'ramda';
import { Table, Land, UserLike, UserId, Player } from './types';
import logger from './logger';

export const findTable = (tables: Table[]) => (name: string): Table => tables.filter(table => table.name === name).pop()!;

export const findLand = (lands: ReadonlyArray<Land>) => (emoji: string): Land => lands.filter(land => land.emoji === emoji).pop()!;

export const hasTurn = ({ turnIndex, players }: { turnIndex: number, players: ReadonlyArray<Player>}) => (playerLike: UserLike): boolean =>
  players.indexOf(
    players.filter(p => p.id === playerLike.id).pop()!
  ) === turnIndex;

const scoreStep = 10;
export const positionScore = (multiplier: number) => (gameSize: number) => (position: number): number => {
  const invPos = gameSize - position + 1;
  const factor = ((invPos * (invPos / gameSize)) - (gameSize / 2)) * 2;
  const baseScore = Math.round(factor * multiplier / scoreStep / gameSize);
  const score = baseScore * scoreStep;
  if (JSON.stringify(score) !== `${score}`) {
    logger.error(`bad score for position:${position} gameSize:${gameSize} multiplier:${multiplier}:`, score);
    logger.debug('invPos', invPos);
    logger.debug('factor', factor);
    logger.debug('baseScore', baseScore);
    return 0;
  }
  return score;
};

export const groupedPlayerPositions = (table: Table): (player: Player) => number => {
  const idLandCounts = table.players.map<[UserId, number]>(player => [
    player.id,
    table.lands.filter(R.propEq('color', player.color)).length,
  ]);
  const sorted = R.sortBy(([id, count]) => count)(idLandCounts);
  const reversed = R.reverse(sorted);

  const positions = reversed.reduce((dict, [id, landCount], i) => {
    dict[id] = i + 1;
    return dict;
  }, {} as { [userId: number]: number });
  
  return player => positions[player.id] || 0;
};


export const tablePoints = (table: Table): number =>
  table.points === 0
    ? 50
    : table.points;

export const updateLand = (lands: ReadonlyArray<Land>, target: Land, props: Partial<Land>): ReadonlyArray<Land> => {
  return lands.map(land => {
    if (land.emoji !== target.emoji) {
      return land;
    }
    return { ...land, ...props };
  });
};

export const adjustPlayer = R.curry((index: number, props: Partial<Player>, players: ReadonlyArray<Player>) =>
  R.adjust(player => ({ ...player, ...props }), index, players)
);
