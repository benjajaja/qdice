import * as R from 'ramda';
import {Table, CommandResult, User, Persona, Player, Land} from '../types';
import {now, addSeconds, havePassed} from '../timestamp';
import * as publish from './publish';
import {rand, shuffle} from '../rand';
import logger from '../logger';
import {GAME_START_COUNTDOWN} from '../constants';
import {makePlayer} from './commands';
import nextTurn from './turn';
import {isBorder} from '../maps';

const defaultPersona: Persona = {
  name: 'Personality',
  picture: 'assets/bot_profile_picture.svg',
};
const personas: Persona[] = [
  {...defaultPersona, name: 'Oliva'},
  {...defaultPersona, name: 'Mono'},
  {...defaultPersona, name: 'Cohete'},
  {...defaultPersona, name: 'Chiqui'},
  {...defaultPersona, name: 'Patata'},
  {...defaultPersona, name: 'Paleto'},
  {...defaultPersona, name: 'Cañón'},
  {...defaultPersona, name: 'Cuqui'},
];

export const addBots = (table: Table): CommandResult => {
  const unusedPersonas = personas.filter(p =>
    R.contains(
      p.name,
      table.players.filter(p => p.bot !== null).map(p => p.name),
    ),
  );
  const persona = unusedPersonas[rand(0, unusedPersonas.length - 1)];
  const botUser: User = {
    id: '-1',
    name: persona.name,
    picture: persona.picture,
    level: 1,
    points: 100,
    email: 'bot@skynet',
    networks: [],
    claimed: true,
  };
  const players = table.players.concat([
    {
      ...makePlayer(botUser, 'bot', table.players.length),
      bot: persona,
      ready: true,
    },
  ]);

  let gameStart = table.gameStart;
  logger.debug('addbot', table.startSlots, players.length);
  if (players.length >= table.startSlots) {
    gameStart = addSeconds(GAME_START_COUNTDOWN);

    publish.event({
      type: 'countdown',
      table: table.name,
      players: players,
    });
  } else {
    publish.event({
      type: 'join',
      table: table.name,
      player: {name: botUser.name},
    });
  }
  return {
    type: 'Join',
    players,
    table: {gameStart},
  };
};

export const tickBotTurn = (table: Table): CommandResult => {
  if (!havePassed(0.5, table.turnStart)) {
    return {type: 'Heartbeat'}; // fake noop
  }

  const player = table.players[table.turnIndex];
  if (player.bot === null) {
    throw new Error('cannot tick non-bot');
  }

  const otherLands = table.lands.filter(other => other.color !== player.color);
  const sourceLands = shuffle(
    table.lands.filter(land => land.color === player.color && land.points > 1),
  )
    .map(source => ({
      source,
      targets: otherLands.filter(other =>
        isBorder(table.adjacency, source.emoji, other.emoji),
      ),
    }))
    .filter(attack => attack.targets.length > 0);

  if (sourceLands.length === 0) {
    logger.debug('no possible source');
    return nextTurn('EndTurn', table);
  }

  const attack = sourceLands.reduce<{from: Land; to: Land} | null>(
    (attack, {source, targets}) =>
      targets.reduce((attack, target) => {
        const bestChance = attack
          ? attack.from.points - attack.to.points
          : -Infinity;
        const thisChance = source.points - target.points;
        if (thisChance > bestChance) {
          if (thisChance > 0) {
            return {from: source, to: target};
          }
        }
        return attack;
      }, attack),
    null,
  );

  if (attack === null) {
    logger.debug('no appropiate attack');
    return nextTurn('EndTurn', table);
  }

  const emojiFrom = attack.from.emoji;
  const emojiTo = attack.to.emoji; // shuffled random

  const timestamp = now();
  publish.move(table, {
    from: emojiFrom,
    to: emojiTo,
  });
  return {
    type: 'Attack',
    table: {
      turnStart: timestamp,
      turnActivity: true,
      attack: {
        start: timestamp,
        from: emojiFrom,
        to: emojiTo,
      },
    },
  };
};
