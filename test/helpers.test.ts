import * as assert from "assert";
import * as R from "ramda";
import * as helpers from "../helpers";
import { Table, Elimination, Player, Color } from "../types";
import {
  ELIMINATION_REASON_SURRENDER,
  ELIMINATION_REASON_DIE,
  ELIMINATION_REASON_OUT,
} from "../constants";

describe("Helpers", function() {
  describe("positionScore", () => {
    it("should rank 1-2", () => {
      const score = helpers.positionScore(100)(2);
      assert.deepEqual(
        [100, -50],
        R.range(1, 3).map(position => score(position))
      );
    });
    it("should rank 1-3", () => {
      const score = helpers.positionScore(100)(3);
      assert.deepEqual(
        [100, -10, -80],
        R.range(1, 4).map(position => score(position))
      );
    });
    it("should rank 1-7", () => {
      const score = helpers.positionScore(100)(7);
      assert.deepEqual(
        [100, 50, 0, -30, -60, -80, -100],
        R.range(1, 8).map(position => score(position))
      );
    });
    it("should rank 1-3 for 500 table", () => {
      const score = helpers.positionScore(500)(3);
      assert.deepEqual(
        [500, -60, -390],
        R.range(1, 4).map(position => score(position))
      );
    });
  });

  describe.skip("Player Positions", () => {
    describe("Grouped", () => {
      it("groups two first players", () => {
        const players = [
          { id: "1", color: 1 },
          { id: "2", color: 2 },
        ];
        const lands = [{ color: 1 }, { color: 1 }, { color: 2 }, { color: 2 }];
        assert.equal(
          helpers.groupedPlayerPositions({ players, lands })(players[0]),
          1
        );
        assert.equal(
          helpers.groupedPlayerPositions({ players, lands })(players[1]),
          1
        );
      });
      it("groups two first players and one third player", () => {
        const players = [
          { id: "1", color: 1 },
          { id: "2", color: 2 },
          { id: "3", color: 3 },
        ];
        const lands = [
          { color: 1 },
          { color: 1 },
          { color: 3 },
          { color: 3 },
          { color: 2 },
        ];
        assert.equal(
          helpers.groupedPlayerPositions({ players, lands })(players[0]),
          1
        );
        assert.equal(
          helpers.groupedPlayerPositions({ players, lands })(players[1]),
          3
        );
        assert.equal(
          helpers.groupedPlayerPositions({ players, lands })(players[2]),
          1
        );
      });
      it("groups three first players, one 4rth and two 5th", () => {
        const players = [
          { id: "1", color: 1 },
          { id: "2", color: 2 },
          { id: "3", color: 3 },
          { id: "4", color: 4 },
          { id: "5", color: 5 },
          { id: "6", color: 6 },
        ];
        const lands = [
          { color: 1 },
          { color: 1 },
          { color: 1 },
          { color: 3 },
          { color: 3 },
          { color: 3 },
          { color: 4 },
          { color: 4 },
          { color: 4 },

          { color: 5 },
          { color: 5 },

          { color: 2 },
          { color: 6 },
        ];
        assert.equal(
          helpers.groupedPlayerPositions({ players, lands })(players[0]),
          1
        );
        assert.equal(
          helpers.groupedPlayerPositions({ players, lands })(players[1]),
          5
        );
        assert.equal(
          helpers.groupedPlayerPositions({ players, lands })(players[2]),
          1
        );
        assert.equal(
          helpers.groupedPlayerPositions({ players, lands })(players[3]),
          1
        );
        assert.equal(
          helpers.groupedPlayerPositions({ players, lands })(players[4]),
          4
        );
        assert.equal(
          helpers.groupedPlayerPositions({ players, lands })(players[5]),
          5
        );
      });
    });
  });

  describe("removePlayerCascade", () => {
    it("kill", () => {
      const players: Player[] = [
        { id: "a" } as any,
        { id: "b" } as any,
        { id: "c" } as any,
      ];

      const player = players[0];
      const elimination: Elimination = {
        player,
        position: players.length,
        reason: ELIMINATION_REASON_DIE,
        source: {
          player: players[2],
          points: 10,
        },
      };
      const [
        players_,
        lands_,
        turnIndex,
        eliminations,
      ] = helpers.removePlayerCascade(players, [], player, 2, elimination, 100);

      assert.deepEqual(turnIndex, 1);
      assert.deepEqual(players_, [players[1], players[2]]);
      assert.deepEqual(eliminations, [elimination]);
    });

    it("surrender current turn", () => {
      const players: Player[] = [
        { id: "a" } as any,
        { id: "b", flag: 3 } as any,
        { id: "c" } as any,
      ];

      const player = players[1];
      const elimination: Elimination = {
        player,
        position: players.length,
        reason: ELIMINATION_REASON_SURRENDER,
        source: {
          flag: player.flag!,
          under: null,
        },
      };
      const [
        players_,
        lands_,
        turnIndex,
        eliminations,
      ] = helpers.removePlayerCascade(players, [], player, 1, elimination, 100);

      assert.deepEqual(turnIndex, 1);
      assert.deepEqual(players_, [players[0], players[2]]);
      assert.deepEqual(eliminations, [elimination]);
    });

    it("surrender current turn wraps turnIndex", () => {
      const players: Player[] = [
        { id: "a" } as any,
        { id: "b" } as any,
        { id: "c", flag: 3 } as any,
      ];

      const player = players[2];
      const elimination: Elimination = {
        player,
        position: players.length,
        reason: ELIMINATION_REASON_SURRENDER,
        source: {
          flag: player.flag!,
          under: null,
        },
      };
      const [
        players_,
        lands_,
        turnIndex,
        eliminations,
      ] = helpers.removePlayerCascade(players, [], player, 2, elimination, 100);

      assert.deepEqual(turnIndex, 0);
      assert.deepEqual(players_, [players[0], players[1]]);
      assert.deepEqual(eliminations, [elimination]);
    });

    it("surrender current turn wraps turnIndex next", () => {
      const players: Player[] = [
        { id: "a", flag: 3 } as any,
        { id: "b" } as any,
        { id: "c" } as any,
      ];

      const player = players[0];
      const elimination: Elimination = {
        player,
        position: players.length,
        reason: ELIMINATION_REASON_SURRENDER,
        source: {
          flag: player.flag!,
          under: null,
        },
      };
      const [
        players_,
        lands_,
        turnIndex,
        eliminations,
      ] = helpers.removePlayerCascade(players, [], player, 2, elimination, 100);

      assert.deepEqual(turnIndex, 1);
      assert.deepEqual(players_, [players[1], players[2]]);
      assert.deepEqual(players_[turnIndex].id, "c");
      assert.deepEqual(eliminations, [elimination]);
    });

    it("surrender out of turn", () => {
      const players: Player[] = [
        { id: "a", color: Color.Red } as any,
        { id: "b" } as any,
        { id: "c", flag: 3 } as any,
        { id: "d", flag: 4 } as any,
      ];

      const player = players[3];
      const elimination: Elimination = {
        player,
        position: players.length,
        reason: ELIMINATION_REASON_SURRENDER,
        source: {
          flag: player.flag!,
          under: {
            player: players[3],
            points: 50,
          },
        },
      };
      const [
        players_,
        lands_,
        turnIndex,
        eliminations,
      ] = helpers.removePlayerCascade(
        players,
        [{ color: Color.Red } as any],
        player,
        3,
        elimination,
        100
      );

      assert.deepEqual(turnIndex, 0);
      assert.deepEqual(players_, [players[0], players[1]]);
      assert.deepEqual(eliminations, [
        elimination,
        {
          player: players[2],
          position: 3,
          reason: ELIMINATION_REASON_SURRENDER,
          source: {
            flag: players[2].flag!,
            under: null,
          },
        },
      ]);
    });

    it("surrender cascade all", () => {
      const players: Player[] = [
        { id: "a" } as any,
        { id: "b", flag: 2 } as any,
        { id: "c", flag: 3 } as any,
        { id: "d", flag: 4 } as any,
      ];

      const player = players[3];
      const elimination: Elimination = {
        player,
        position: 4,
        reason: ELIMINATION_REASON_SURRENDER,
        source: {
          flag: player.flag!,
          under: null,
        },
      };
      const [
        players_,
        lands_,
        turnIndex,
        eliminations,
      ] = helpers.removePlayerCascade(players, [], player, 3, elimination, 100);

      assert.deepEqual(turnIndex, 0);
      assert.deepEqual(players_, [players[0]]);
      assert.deepEqual(eliminations, [
        elimination,
        {
          player: players[2],
          position: 3,
          reason: ELIMINATION_REASON_SURRENDER,
          source: {
            flag: players[2].flag!,
            under: null,
          },
        },
        {
          player: players[1],
          position: 2,
          reason: ELIMINATION_REASON_SURRENDER,
          source: {
            flag: players[1].flag!,
            under: {
              player: players[0],
              points: 100,
            },
          },
        },
      ]);
    });

    it("surrender cascade attack", () => {
      const players: Player[] = [
        { id: "a" } as any,
        { id: "b", flag: 2 } as any,
        { id: "c" } as any,
      ];

      const player = players[2];
      const elimination: Elimination = {
        player,
        position: 3,
        reason: ELIMINATION_REASON_DIE,
        source: {
          player: null!,
          points: 1,
        },
      };
      const [
        players_,
        lands_,
        turnIndex,
        eliminations,
      ] = helpers.removePlayerCascade(players, [], player, 1, elimination, 100);

      assert.deepEqual(turnIndex, 0);
      assert.deepEqual(players_, [players[0]]);
      assert.deepEqual(eliminations, [
        elimination,
        {
          player: players[1],
          position: 2,
          reason: ELIMINATION_REASON_SURRENDER,
          source: {
            flag: players[1].flag!,
            under: {
              player: players[0],
              points: 100,
            },
          },
        },
      ]);
    });

    it("out", () => {
      const players: Player[] = [
        { id: "a" } as any,
        { id: "b" } as any,
        { id: "c" } as any,
      ];

      const player = players[1];
      const elimination: Elimination = {
        player,
        position: players.length,
        reason: ELIMINATION_REASON_OUT,
        source: {
          turns: 5,
        },
      };
      const [
        players_,
        lands_,
        turnIndex,
        eliminations,
      ] = helpers.removePlayerCascade(players, [], player, 1, elimination, 100);

      assert.deepEqual(turnIndex, 1);
      assert.deepEqual(players_, [players[0], players[2]]);
      assert.deepEqual(eliminations, [elimination]);
    });
  });
});
