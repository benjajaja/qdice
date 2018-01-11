const R = require('ramda');
const probe = require('pmx').probe();
const publish = require('./publish');
const { rand } = require('../rand');
const {
  STATUS_PLAYING,
} = require('../constants');

const startCounter = probe.counter({
  name : 'Games started',
});

const randomPoints = stackSize => {
  const r = Math.random();
  if (r > 0.98)
    return Math.min(8, Math.floor(stackSize / 2 + 1));
  else if (r > 0.90)
    return Math.floor(stackSize / 2);
  return rand(1, Math.floor(stackSize / 4));
};

function shuffle(a) {
  for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

const randomLandOrder = table => {
  const landCount = table.lands.length;
  const colorsCount = landCount - (landCount % table.players.length);
  return shuffle(table.lands.slice()).slice(0, colorsCount);
};

module.exports = table => {
  table.status = STATUS_PLAYING;
  table.gameStart = Date.now();

  table.lands = table.lands.map(land => Object.assign({}, land, {
    points: randomPoints(table.stackSize),
    color: -1,
  }));

  const shuffledLands = randomLandOrder(table);

  shuffledLands.forEach((land, index) => {
    const player = table.players[index % table.players.length];
    land.color = player.color;
    land.points = 1;//randomPoints(table.stackSize);
  });
  table.players.forEach((player, index) => {
    const landCount = table.lands.length;
    const colorsCount = landCount - (landCount % table.players.length);
    const playerLands = shuffledLands.filter(R.propEq('color', player.color));
    const playerLandCount = playerLands.length;

    R.range(0, index + 2).forEach(i => {
      playerLands[i].points =
        Math.max(1, Math.min(table.stackSize / 2, playerLands[i].points + 1 + index));
    });
    if (index === table.players.length - 1) {
      playerLands[0].points = Math.floor(table.stackSize / 2) + 1;
    }
  });
  
  table.turnIndex = 0;
  table.turnStarted = Math.floor(Date.now() / 1000);
  table.turnActivity = false;
  table.playerStartCount = table.players.length;
  publish.tableStatus(table);
  publish.event({
    type: 'start',
    table: table.name,
  });
  startCounter.inc();
  return table;
};

