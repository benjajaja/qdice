const R = require('ramda');
const { rand, diceRoll } = require('../rand');
const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
  TURN_SECONDS,
  COLOR_NEUTRAL,
} = require('../constants');
const { findLand, hasTurn } = require('../helpers');
const publish = require('./publish');
const { isBorder } = require('../maps');

module.exports = (user, table, [emojiFrom, emojiTo], res, next) => {
  if (table.status !== STATUS_PLAYING) {
    return next(new Error('game not running'));
  }
  if (!hasTurn(table)(user)) {
    return next(new Error('out of turn'));
  }
  const find = findLand(table.lands);
  const fromLand = find(emojiFrom);
  const toLand = find(emojiTo);
  if (!fromLand || !toLand) {
    return next(new Error('land not found'));
  }
  if (fromLand.color === COLOR_NEUTRAL) {
    return next(new Error('illegal move (same color)'));
  }
  if (fromLand.color === toLand.color) {
    return next(new Error('illegal move (same color)'));
  }
  if (!isBorder(table.adjacency, emojiFrom, emojiTo)) {
    return next(new Error('illegal move (not adjacent)'));
  }

  table.turnStarted = Math.floor(Date.now() / 1000);
  setTimeout(() => {
    try {
      const [fromRoll, toRoll, isSuccess] = diceRoll(fromLand.points, toLand.points);
      console.log('rolled');
      if (isSuccess) {
        const loser = R.find(R.propEq('color', toLand.color), table.players);
        toLand.points = fromLand.points - 1;
        toLand.color = fromLand.color;
        if (loser && R.filter(R.propEq('color', loser.color), table.lands).length === 0) {
          const turnPlayer = table.players[table.turnIndex];
          table.players = table.players.filter(R.complement(R.equals(loser)));
          if (table.players.length === 1) {
            endGame(table);
          }
          table.turnIndex = table.players.indexOf(turnPlayer);
        }
      }
      fromLand.points = 1;

      publish.roll(table, {
        from: { emoji: emojiFrom, roll: fromRoll },
        to: { emoji: emojiTo, roll: toRoll },
      });

      table.turnStarted = Math.floor(Date.now() / 1000);
      publish.tableStatus(table);
    } catch (e) {
      console.error(e);
    }
  }, 500);
  console.log('rolling...');
  publish.move(table, {
    from: emojiFrom,
    to: emojiTo,
  });
  res.send(204);
  next();
};

const endGame = table => {
  table.players = [];
  table.status = STATUS_FINISHED;
  table.turnIndex = -1;
  table.gameStart = 0;
};

