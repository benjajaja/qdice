const R = require('ramda');
const probe = require('pmx').probe();

const maps = require('./maps');
const { rand, diceRoll } = require('./rand');
const publish = require('./table/publish');
const nextTurn = require('./table/turn');
const {
  STATUS_PAUSED,
  STATUS_PLAYING,
  STATUS_FINISHED,
} = require('./constants');


const keys = ['Melchor', 'Miño', 'Avocado', ]; //'Sabicas' ];


const Table = name => ({
  name,
  players: [],
  playerSlots: 2,
  status: STATUS_PAUSED,
  turnIndex: -1,
  turnStarted: 0,
  lands: [],
  stackSize: 4,
});


const loadLands = table => {
  console.time(`table ${table.name} loaded`);
  const [ lands, adjacency ] = maps.loadMap(table.name);
  console.timeEnd(`table ${table.name} loaded`);
  return Object.assign({}, table, { lands, adjacency });
};

const Player = user => ({
  id: user.id,
  name: user.name,
  picture: user.picture || '',
  color: -1,
  reserveDice: 0,
  derived: {
    connectedLands: 0,
    totalLands: 0,
    currentDice: 0,
  },
});
  
console.log('loading tables and calculating adjacency matrices...');
const tables = keys.map(key =>loadLands(Table(key)));
tables[2].playerSlots = 3;

module.exports.getTables = function() {
  return tables;
};

const findTable = tables => name => tables.filter(table => table.name === name).pop();
const findLand = lands => emoji => lands.filter(land => land.emoji === emoji).pop();
const hasTurn = table => playerLike =>
  table.players.indexOf(
    table.players.filter(p => p.id === playerLike.id).pop()
  ) === table.turnIndex;

module.exports.command = function(req, res, next) {
  const table = findTable(tables)(req.context.tableName);
  if (!table) {
		return next(new Error('table not found: ' + req.context.tableName));
	}
  const command = req.context.command;
  switch (command) {
    case 'Enter':
      enter(req.user, table, res, next);
      break;
    case 'Join':
      join(req.user, table, res, next);
      break;
    case 'Leave':
      leave(req.user, table, res, next);
      break;
    case 'Attack':
      attack(req.user, table, req.body, res, next);
      break;
    case 'EndTurn':
      endTurn(req.user, table, res, next);
      break;
    default:
      return next(new Error('Unknown command: ' + command));
  }
};

const enterCounter = probe.counter({
  name : 'Table enter',
});
const enter = (user, table, res, next) => {
  const player = Player(user);
  // TODO: publish only to client
  publish.tableStatus(table);
  enterCounter.inc();
  res.send(204);
  next();
};

const join = (user, table, res, next) => {
  console.log('join', user.name);
  if (table.status === STATUS_PLAYING) {
    res.send(406);
    return next();
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (existing) {
    return next(new Error('already joined'));
  } else {
    table.players.push(Player(user));
  }

  table.players = table.players.map((player, index) => Object.assign(player, { color: index + 1}));
  if (table.players.length === table.playerSlots) {
    startGame(table);
  } else {
    publish.tableStatus(table);
  }
  res.send(204);
  next();
};


const leave = (user, table, res, next) => {
  if (table.status === STATUS_PLAYING) {
    res.send(406);
    return next();
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    return next(new Error('not joined'));
  } else {
    table.players = table.players.filter(p => p !== existing);
  }
  table.players = table.players.map((player, index) => Object.assign(player, { color: index + 1 }));
  publish.tableStatus(table);
  res.send(204);
  next();
};

const attack = (user, table, [emojiFrom, emojiTo], res, next) => {
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
          console.log('player lost:', loser);
          if (table.players.length === 1) {
            table.players = [];
            table.status = STATUS_FINISHED;
            table.turnIndex = -1;
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

const endTurn = (user, table, res, next) => {
  if (table.status !== STATUS_PLAYING) {
    return next(new Error('game not running'));
  }
  if (!hasTurn(table)(user)) {
    return next(new Error('out of turn'));
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    return next(new Error('not playing'));
  }

  nextTurn(table);
  publish.tableStatus(table);
  res.send(204);
  next();
};



const startGame = table => {
  table.status = STATUS_PLAYING;

  table.lands = table.lands.map(land => Object.assign({}, land, {
    points: ((r) => {
      if (r > 0.98)
        return Math.min(8, table.stackSize + 1);
      else if (r > 0.90)
        return table.stackSize;
      return rand(1, table.stackSize - 1);
    })(Math.random()),
    color: -1,
  }));
  const startLands = (() => {
    function shuffle(a) {
      for (let i = a.length - 1; i > 0; i--) {
          const j = Math.floor(Math.random() * (i + 1));
          [a[i], a[j]] = [a[j], a[i]];
      }
      return a;
    }
    return shuffle(table.lands.slice()).slice(0, table.players.length);
  })();
  table.players.forEach((player, index) => {
    const land = startLands[index];
    land.color = player.color;
    land.points = 4;
  });
  
  table = nextTurn(table);
  publish.tableStatus(table);
  return table;
};

const tick = require('./table/tick');
module.exports.tick = () => tick(module.exports.getTables());

module.exports.setMqtt = (...args) => publish.setMqtt(...args);

