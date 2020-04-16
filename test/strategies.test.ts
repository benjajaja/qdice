import * as assert from "assert";
import { Table, Color, Land, Player, BotPlayer, UserId } from "../types";
import {
  Source,
  move,
  pickTactic,
  tactics,
  wouldRefillAll,
} from "../table/bot_strategies";

const mkLand = (
  points: number,
  color: Color = Color.Red,
  emoji: string = Math.random().toString()
): Land => ({
  points,
  color,
  emoji,
  capital: false,
});

const mkPlayer = (color: Color = Color.Red): Player =>
  ({
    id: Math.random(),
    color,
    reserveDice: 0,
  } as any);

const mkBotPlayer = (
  color: Color = Color.Red,
  lastAgressor?: UserId
): BotPlayer =>
  ({
    id: Math.random(),
    color,
    bot: {
      state: {
        lastAgressor,
      },
    },
  } as any);

const mkTable = (props?: Partial<Table>): Table =>
  ({
    players: [mkPlayer(Color.Red), mkPlayer(Color.Blue), mkPlayer(Color.Green)],
    lands: [],
    ...props,
  } as any);

describe.skip("Move tactics", function() {
  describe("move with probable defeat", () => {
    const sources: Source[] = [
      {
        source: mkLand(2),
        targets: [mkLand(3)],
      },
    ];
    it("RandomCareful should not attack", () => {
      const attack = move("RandomCareful")(sources, mkBotPlayer(), mkTable())!;
      assert.strictEqual(null, attack);
    });
    it("RandomCareless should attack", () => {
      const attack = move("RandomCareless")(sources, mkBotPlayer(), mkTable())!;
      assert.deepEqual(attack.from, sources[0].source);
      assert.deepEqual(attack.to, sources[0].targets[0]);
    });
    it("Revengeful should not attack", () => {
      const attack = move("Revengeful")(
        sources,
        mkBotPlayer(),
        mkTable({
          lands: [mkLand(4, Color.Red)],
        })
      )!;
      assert.strictEqual(null, attack);
    });
  });
  describe("move with probable win", () => {
    const sources: Source[] = [
      {
        source: mkLand(2),
        targets: [mkLand(1)],
      },
    ];
    it("RandomCareful should attack", () => {
      const attack = move("RandomCareful")(sources, mkBotPlayer(), mkTable())!;
      assert.deepEqual(attack.from, sources[0].source);
      assert.deepEqual(attack.to, sources[0].targets[0]);
    });
    it("RandomCareless should attack", () => {
      const attack = move("RandomCareless")(sources, mkBotPlayer(), mkTable())!;
      assert.deepEqual(attack.from, sources[0].source);
      assert.deepEqual(attack.to, sources[0].targets[0]);
    });
    it("Revengeful should not attack", () => {
      const attack = move("Revengeful")(
        sources,
        mkBotPlayer(),
        mkTable({
          lands: [mkLand(4, Color.Red)],
        })
      )!;
      assert.strictEqual(null, attack);
    });
  });
});

describe("Pick tactic from strategy", () => {
  describe("Revengeful", () => {
    it("focus on lastAgressor", () => {
      const bot = mkBotPlayer();
      const table = mkTable({
        players: [bot, mkPlayer(Color.Blue), mkPlayer(Color.Green)],
        lands: [mkLand(4, bot.color)],
      });
      bot.bot.state.lastAgressor = table.players[1].id;
      const tactic = pickTactic("Revengeful", bot, table);
      assert.strictEqual(tactic.name, "focusColor");
    });
    it("focus on neutral if no agressor", () => {
      const bot = mkBotPlayer();
      const table = mkTable({
        players: [bot, mkPlayer(Color.Blue), mkPlayer(Color.Green)],
        lands: [mkLand(4, bot.color)],
      });
      const tactic = pickTactic("Revengeful", bot, table);
      assert.strictEqual(tactic.name, "focusColor");
      assert.strictEqual(
        tactic(-Infinity, mkLand(4, Color.Red), mkLand(1, Color.Blue)),
        undefined
      );
      assert.ok(
        tactic(-Infinity, mkLand(4, Color.Red), mkLand(1, Color.Neutral)) !==
          undefined
      );
    });
  });
});

describe("Tactics", () => {
  describe("Reconnect", () => {
    const bot = mkBotPlayer();
    const table = mkTable({
      players: [bot, mkPlayer(Color.Blue), mkPlayer(Color.Green)],
      lands: [
        mkLand(1, bot.color, "A"),
        mkLand(1, bot.color, "B"),
        mkLand(1, Color.Yellow, "C"), // connect A
        mkLand(1, Color.Cyan, "D"), // connects A-B
      ],
      adjacency: {
        indexes: {
          A: 0,
          B: 1,
          C: 2,
          D: 3,
        },
        matrix: [
          [true, false, true, true],
          [false, true, false, true],
          [true, false, true, false],
          [true, true, false, true],
        ],
      },
    });
    it("attacks to reconnect", () => {
      const attack = tactics.reconnect(
        -Infinity,
        table.lands[0],
        table.lands[3],
        bot,
        table
      );
      assert.strictEqual(attack!.to.emoji, "D");
    });
    it("does not attack if no reconnect", () => {
      const attack = tactics.reconnect(
        -Infinity,
        table.lands[0],
        table.lands[2],
        bot,
        table
      );
      assert.strictEqual(attack, undefined);
    });
  });
});

describe("Refill all", () => {
  const player = mkPlayer(Color.Red);
  const fullLand = () => mkLand(8, Color.Red);
  it("detects would-refill-all", () => {
    assert.strictEqual(wouldRefillAll(player, mkTable()), false);

    assert.strictEqual(
      wouldRefillAll(
        mkPlayer(),
        mkTable({
          lands: [
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
          ],
        })
      ),
      true
    );
  });

  it("detects would-refill-all with some lands not full", () => {
    assert.strictEqual(
      wouldRefillAll(
        mkPlayer(),
        mkTable({
          lands: [
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            mkLand(7, Color.Red),
          ],
        })
      ),
      true
    );
    assert.strictEqual(
      wouldRefillAll(
        mkPlayer(),
        mkTable({
          lands: [
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            mkLand(1, Color.Red),

            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            mkLand(1, Color.Red),

            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
          ],
        })
      ),
      true
    );
  });

  it("detects would-not-refill-all with some lands not full", () => {
    assert.strictEqual(
      wouldRefillAll(
        mkPlayer(),
        mkTable({
          lands: [
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            mkLand(1, Color.Red),

            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            mkLand(1, Color.Red),

            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            fullLand(),
            mkLand(4, Color.Red),
          ],
        })
      ),
      false
    );
  });
});
