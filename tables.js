const fs = require('fs');
const R = require('ramda');

const keys = ['Melchor', 'Miño', 'Sabicas'];
module.exports.keys = keys;

const T_CLIENTS = 'clients';

const STATUS_PAUSED = 'PAUSED';
const STATUS_PLAYING = 'PLAYING';
const STATUS_FINISHED = 'FINISHED';

const TURN_SECONDS = 10;

const Table = name => ({
  name,
  players: [],
  spectators: [],
  playerSlots: 2,
  status: STATUS_PAUSED,
  turnIndex: -1,
  turnStarted: 0,
  lands: [],
});

const rand = (min, max) => Math.floor(Math.random() * (max + 1 - min)) + min;

const diceRoll = (fromPoints, toPoints) => {
  const fromRoll = R.range(0, fromPoints).map(_ => rand(1, 6));
  const toRoll = R.range(0, toPoints).map(_ => rand(1, 6));
  const success = R.sum(fromRoll) > R.sum(toRoll);
  return [fromRoll, toRoll, success];
};


const loadLands = table => {
  const rawMap = fs.readFileSync('./maps/' + table.name + '.emoji')
    .toString().split('\n').filter(line => line !== '');
  const regex = new RegExp('〿|\\u3000|[\\uD800-\\uDBFF][\\uDC00-\\uDFFF]', 'gi');

  const rows = rawMap.map(line => {
    const results = [];
    let result;
    let index = 0;
    while (result = regex.exec(line)){
      results.push([index, result[0]]);
      index++;
    }
    return results;
  });
  //const maxWidth = rows.map(row => row.length).reduce((max, width) => Math.max(max, width));
  const lands = R.uniq(rows.map(row => row.map(cell => cell[1])).reduce(R.concat, []))
    .filter(R.complement(R.equals('〿')))
    .filter(R.complement(R.equals('\u3000')))
    .map(emoji => ({
      emoji: emoji,
      color: -1,
      points: rand(1, 5),
    }));
  table.lands = lands;
  return table;
};

const Player = user => ({
  id: user.id,
  name: user.name,
  picture: user.picture,
  color: -1,
});
  
const tables = keys.map(key =>loadLands(Table(key)));
const tableTimeouts = keys.reduce((obj, key) => Object.assign(obj, { [key]: null }));

const findTable = tables => name => tables.filter(table => table.name === name).pop();
const findLand = lands => emoji => lands.filter(land => land.emoji === emoji).pop();

module.exports.command = function(req, res, next) {
  const table = findTable(tables)(req.context.tableName);
  if (!table) {
		throw new Error('table not found: ' + req.context.tableName);
	}
  const command = req.context.command;
  switch (command) {
    case 'Enter':
      enter(req.user, table, req);
      break;
    case 'Join':
      join(req.user, table, req);
      break;
    case 'Leave':
      leave(req.user, table, req);
      break;
    case 'Attack':
      attack(req.user, table, req.body);
      break;
    case 'EndTurn':
      endTurn(req.user, table, req);
      break;
    default:
      throw new Error('Unknown command: ' + command);
  }
  res.send(204);
  next();
};

const enter = (user, table) => {
  const player = Player(user);
  const existing = table.spectators.filter(p => p.id === player.id).pop();
  if (existing) {
    table.spectators[table.spectators.indexOf(existing)] =
      Object.assign({}, existing, player);
  } else {
    table.spectators.push(player);
  }
  publishTableStatus(table);
};

const join = (user, table) => {
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (existing) {
    throw new Error('already joined');
  } else {
    table.players.push(Player(user));
  }

  if (table.players.length === table.playerSlots) {
    startGame(table);
  } else {
    publishTableStatus(table);
  }
};


const leave = (user, table) => {
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    throw new Error('not joined');
  } else {
    table.players = table.players.filter(p => p !== existing);
  }
  publishTableStatus(table);
};

const attack = (user, table, [emojiFrom, emojiTo]) => {
  if (table.status !== STATUS_PLAYING) {
    throw new Error('game not running');
  }
  const find = findLand(table.lands);
  const fromLand = find(emojiFrom);
  const toLand = find(emojiTo);
  if (!fromLand || !toLand) {
    throw new Error('land not found');
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
          table.players = table.players.filter(R.complement(R.equals(loser)));
          console.log('player lost:', loser);
          if (table.players.length === 1) {
            table.players = [];
            table.status = STATUS_FINISHED;
            table.turnIndex = -1;
          }
        }
      }
      fromLand.points = 1;

      console.log('publish roll and table');
      publishRoll(table, {
        from: { emoji: emojiFrom, roll: fromRoll },
        to: { emoji: emojiTo, roll: toRoll },
      });

      table.turnStarted = Math.floor(Date.now() / 1000);
      publishTableStatus(table);
    } catch (e) {
      console.error(e);
    }
  }, 500);
  console.log('rolling...');
  publishTableStatus(table);
};

const endTurn = (user, table) => {
  if (table.status !== STATUS_PLAYING) {
    throw new Error('game not running');
  }
  const existing = table.players.filter(p => p.id === user.id).pop();
  if (!existing) {
    throw new Error('not playing');
  }

  if (table.players.indexOf(existing) !== table.turnIndex) {
    throw new Error('not your turn');
  }

  nextTurn(table);
  publishTableStatus(table);
};


let client;
module.exports.setMqtt = client_ => {
  client = client_;
  client.on('message', (topic, message) => {
    if (topic.indexOf('tables/') !== 0) return;
    const [ _, tableName, channel ] = topic.split('/');
    const table = findTable(tables)(tableName);
    if (!table) throw new Error('table not found: ' + tableName);
    const { type, payload } = JSON.parse(message);
    //publishTableStatus(table);
  });
  tables.forEach(publishTableStatus);
};

const publishTableStatus = table => {
  client.publish('tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'update',
      payload: table,
    }),
    undefined,
    (err) => {
			if (err) {
				console.log(err, 'tables/' + table.name + '/clients update', table);
			}
		}
  );
};

const publishRoll = (table, roll) => {
  client.publish('tables/' + table.name + '/clients',
    JSON.stringify({
      type: 'roll',
      payload: roll,
    }),
    undefined,
    (err) => {
			if (err) {
				console.log(err, 'tables/' + table.name + '/clients roll', roll);
			}
		}
  );
};

const startGame = table => {
  table.status = STATUS_PLAYING;
  table.players = table.players
    .map((player, index) => Object.assign({}, player, { color: index + 1 }));

  table.lands = table.lands.map(land => Object.assign({}, land, {
    points: rand(1, 5),
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
  publishTableStatus(table);
  return table;
};

const nextTurn = table => {
  if (table.turnIndex !== -1) {
    const currentTurnPlayer = table.players[table.turnIndex];
    const playerLands = table.lands.filter(land => land.color === currentTurnPlayer.color);
    const newDies = playerLands.length; // TODO: find only connected

    R.range(0, newDies).forEach(i => {
      const targets = playerLands.filter(land => land.points < 8);
      if (targets.length === 0) {
        // TODO: reserve dies
      } else {
        const target = targets[rand(0, targets.length - 1)];
        target.points += 1;
      }
    });
  }

  const nextIndex = (i => i + 1 < table.playerSlots ? i + 1 : 0)(table.turnIndex);
  table.turnIndex = nextIndex;
  table.turnStarted = Math.floor(Date.now() / 1000);
  return table;
};

module.exports.tick = () => {
  tables.filter(table => table.status === STATUS_PLAYING)
    .forEach(table => {
    if (table.turnStarted < Date.now() / 1000 - TURN_SECONDS) {
      nextTurn(table);
      publishTableStatus(table);
    }
  });
};

