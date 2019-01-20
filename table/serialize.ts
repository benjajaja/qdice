import * as R from 'ramda';

import * as maps from '../maps';
import { groupedPlayerPositions, positionScore, tablePoints } from '../helpers';
import { Table, Player } from '../types';
import logger from '../logger';

export const serializeTable = (table: Table) => {

  const players = table.players.map(serializePlayer(table));  

  const lands = table.lands.map(({ emoji, color, points }) => [emoji, color, points]);

  return {
    tag: table.tag,
    name: table.name,
    mapName: table.mapName,
    playerSlots: table.playerSlots,
    status: table.status,
    turnIndex: table.turnIndex,
    turnStart: Math.floor(table.turnStart / 1000),
    gameStart: Math.floor(table.gameStart / 1000),
    turnCount: table.turnCount,
    roundCount: table.roundCount,
    players: players,
    lands: lands,
    canFlag: table.roundCount >= table.noFlagRounds,
    watchCount: table.watching.length,
  };
};


export const serializePlayer = (table: Table) => {
  const derived = computePlayerDerived(table);
  return (player: Player) => {
    logger.debug('serializePlayer', derived(player));
    return Object.assign({}, R.pick([
      'id', 'name', 'picture', 'color', 'reserveDice', 'out', 'outTurns', 'points', 'level', 'score', 'flag',
    ])(player), { derived: derived(player) });
  };
};

export type PlayerDerived = {
  connectedLands: number;
  totalLands: number;
  currentDice: number;
  position: number;
  score: number;
};

export const computePlayerDerived = (table: Table) => {
  const positions = groupedPlayerPositions(table);
  const getScore = positionScore(tablePoints(table))(table.playerStartCount);
  return (player: Player): PlayerDerived => {
    const lands = table.lands.filter(R.propEq('color', player.color));
    const connectedLands = maps.countConnectedLands(table)(player.color);
    const position = positions(player);
    const score = player.score + getScore(position);
    return {
      connectedLands,
      totalLands: lands.length,
      currentDice: R.sum(lands.map(R.prop('points'))),
      position,
      score,
    };
  };
};
