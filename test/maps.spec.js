var assert = require('assert');
const R = require('ramda');
const maps = require('../maps');

describe('Array', function() {
  describe('#indexOf()', function() {
    it('should return -1 when the value is not present', function() {
      assert.equal([1,2,3].indexOf(4), -1);
    });
  });
});

describe('Maps', () => {
  describe('Loading', () => {
    it('should load a map', () => {
      const lands = maps.loadMap('Melchor');
      assert.equal(lands.length, 13);

      landSpecs = [
        null,
        null,
        {
          emoji: '🍋',
          cells: [
            [0,2,-2],
            [1,2,-3],
            [2,2,-4],
            [0,3,-3],
            [1,3,-4],
            [2,3,-5],
            [0,4,-4],
            [1,4,-5],
            [0,5,-5],
          ].map(([x,y,z]) => ({x,y,z}))
        },
        // { cells = [IntCubeHex (0,2,-2),IntCubeHex (1,2,-3),IntCubeHex (2,2,-4),IntCubeHex (0,3,-3),IntCubeHex (1,3,-4),IntCubeHex (2,3,-5),IntCubeHex (0,4,-4),IntCubeHex (1,4,-5),IntCubeHex (0,5,-5)], color = Neutral, emoji = "🍋", points = 1 }
      ];
      lands.forEach((land, i) => {
        assert.equal(typeof land.emoji, 'string');
        const spec = landSpecs[i];
        if (spec) {
          assert.strictEqual(land.emoji, spec.emoji);
          assert.strictEqual(land.color, -1);
          assert.strictEqual(typeof land.points, 'number');
          assert(land.points > 0);
          assert(land.points <= 8);

          assert.equal(land.cells instanceof Array, true);
          land.cells.forEach((cell, i) => {
            //assert.deepEqual(cell, spec.cells[i], `#${i} ${JSON.stringify(cell)} not ${JSON.stringify(spec.cells[i])}`);
          });
        }
      });
    });
  });

  describe('Borders', () => {
    const lands = maps.loadMap('Melchor');
    [
      ['🍋', '🔥', true],
      ['🔥', '🔥', true],
      ['🍋', '💰', false],
      ['😺', '🐵', true],
      ['🐵', '🐵', true],
      ['🐙', '🐵', false],
    ].forEach(([from, to, isBorder]) => {
      it(`${from}  should ${isBorder ? '' : 'NOT '}border ${to}`, () => {
        assert.equal(maps.isBorder(lands, from, to), isBorder, `${[from, to]} expected to border: ${isBorder}`);
      });
    });
  });


  describe('Connected lands count', () => {
    it('should count simple relation', () => {
      const redEmojis = ['🍋', '💰', '🐸', '🐵'];
      const lands = maps.loadMap('Melchor').map(land =>
        Object.assign(land, { color: R.contains(land.emoji, redEmojis) ? 1 : -1 }));

      assert.equal(maps.countConnectedLands(lands)(1), 2);
    });
    it('should count complex relation', () => {
      const redEmojis = ['🍋', '💰', '🐸', '🐵', '🥑', '👑', '🌙', '🌵', '🐙'];
      const lands = maps.loadMap('Melchor').map(land =>
        Object.assign(land, { color: R.contains(land.emoji, redEmojis) ? 1 : -1 }));

      assert.equal(maps.countConnectedLands(lands)(1), 5);
    });
    it('should count simple big relation', () => {
      const redEmojis = ['🍋', '💰', '🐸', '🐵', '🥑', '👑', '🌙', '🌵', '🐙', '🍺'];
      const lands = maps.loadMap('Melchor').map(land =>
        Object.assign(land, { color: R.contains(land.emoji, redEmojis) ? 1 : -1 }));

      assert.equal(maps.countConnectedLands(lands)(1), 9);
    });
    it('should count two equals relations', () => {
      const redEmojis = ['🍋', '💰', '🐸', '🐵', '🥑'];
      const lands = maps.loadMap('Melchor').map(land =>
        Object.assign(land, { color: R.contains(land.emoji, redEmojis) ? 1 : -1 }));

      assert.equal(maps.countConnectedLands(lands)(1), 2);
    });
  });
});
