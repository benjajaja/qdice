const probe = require('pmx').probe();
const nextTurn = require('./turn');
const publish = require('./publish');
const { rand } = require('../rand');
const {
  STATUS_PLAYING,
} = require('../constants');

const startCounter = probe.counter({
  name : 'Games started',
});
module.exports = table => {
  table.status = STATUS_PLAYING;
  table.gameStart = Date.now();

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
  startCounter.inc();
  return table;
};

