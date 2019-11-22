import * as assert from 'assert';
import * as R from 'ramda';
import * as helpers from '../helpers';

describe('Helpers', function() {
  describe('positionScore', () => {
    it('should rank 1-2', () => {
      const score = helpers.positionScore(100)(2);
      assert.deepEqual(
        [100, -50],
        R.range(1, 3).map(position => score(position)),
      );
    });
    it('should rank 1-3', () => {
      const score = helpers.positionScore(100)(3);
      assert.deepEqual(
        [100, -10, -80],
        R.range(1, 4).map(position => score(position)),
      );
    });
    it('should rank 1-7', () => {
      const score = helpers.positionScore(100)(7);
      assert.deepEqual(
        [100, 50, 0, -30, -60, -80, -100],
        R.range(1, 8).map(position => score(position)),
      );
    });
    it('should rank 1-3 for 500 table', () => {
      const score = helpers.positionScore(500)(3);
      assert.deepEqual(
        [500, -60, -390],
        R.range(1, 4).map(position => score(position)),
      );
    });
  });

  describe.skip('Player Positions', () => {
    describe('Grouped', () => {
      it('groups two first players', () => {
        const players = [
          {id: '1', color: 1},
          {id: '2', color: 2},
        ];
        const lands = [{color: 1}, {color: 1}, {color: 2}, {color: 2}];
        assert.equal(
          helpers.groupedPlayerPositions({players, lands})(players[0]),
          1,
        );
        assert.equal(
          helpers.groupedPlayerPositions({players, lands})(players[1]),
          1,
        );
      });
      it('groups two first players and one third player', () => {
        const players = [
          {id: '1', color: 1},
          {id: '2', color: 2},
          {id: '3', color: 3},
        ];
        const lands = [
          {color: 1},
          {color: 1},
          {color: 3},
          {color: 3},
          {color: 2},
        ];
        assert.equal(
          helpers.groupedPlayerPositions({players, lands})(players[0]),
          1,
        );
        assert.equal(
          helpers.groupedPlayerPositions({players, lands})(players[1]),
          3,
        );
        assert.equal(
          helpers.groupedPlayerPositions({players, lands})(players[2]),
          1,
        );
      });
      it('groups three first players, one 4rth and two 5th', () => {
        const players = [
          {id: '1', color: 1},
          {id: '2', color: 2},
          {id: '3', color: 3},
          {id: '4', color: 4},
          {id: '5', color: 5},
          {id: '6', color: 6},
        ];
        const lands = [
          {color: 1},
          {color: 1},
          {color: 1},
          {color: 3},
          {color: 3},
          {color: 3},
          {color: 4},
          {color: 4},
          {color: 4},

          {color: 5},
          {color: 5},

          {color: 2},
          {color: 6},
        ];
        assert.equal(
          helpers.groupedPlayerPositions({players, lands})(players[0]),
          1,
        );
        assert.equal(
          helpers.groupedPlayerPositions({players, lands})(players[1]),
          5,
        );
        assert.equal(
          helpers.groupedPlayerPositions({players, lands})(players[2]),
          1,
        );
        assert.equal(
          helpers.groupedPlayerPositions({players, lands})(players[3]),
          1,
        );
        assert.equal(
          helpers.groupedPlayerPositions({players, lands})(players[4]),
          4,
        );
        assert.equal(
          helpers.groupedPlayerPositions({players, lands})(players[5]),
          5,
        );
      });
    });
  });
});
