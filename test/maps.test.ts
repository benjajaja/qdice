import * as assert from "assert";
import * as R from "ramda";
import * as maps from "../maps";
import * as config from "../tables.config";

describe("Maps", () => {
  describe("Loading", () => {
    it("should load a map", () => {
      const [lands, adjacency] = maps.loadMap("Melchor");
      assert.equal(lands.length, 13);
    });
  });

  describe("Borders of Melchor", () => {
    const [lands, adjacency] = maps.loadMap("Melchor");
    const spec: [string, string, boolean][] = [
      ["🍋", "🔥", true],
      ["🍋", "💰", false],
      ["💰", "🐸", true],
      ["😺", "🐵", true],
      ["😺", "🍺", true],
      ["🐙", "🐵", false],
      ["🐵", "🍺", true],
      ["🐵", "🌵", true],
      ["🌵", "🐵", true],
      ["🐵", "🥑", true],
      ["🌵", "🌙", true],
      ["🔥", "😺", true],
    ];
    spec.forEach(([from, to, isBorder]) => {
      it(`${from}  should ${isBorder ? "" : "NOT "}border ${to}`, () => {
        assert.equal(
          maps.isBorder(adjacency, from, to),
          isBorder,
          `${[from, to].join(" ->")} expected to border: ${isBorder}`
        );
      });
    });
  });

  describe("Borders of Serrano", () => {
    const [lands, adjacency] = maps.loadMap("Serrano");
    const spec: [string, string, boolean][] = [
      ["🏰", "💰", false],
      ["💎", "🍒", false],
      ["🎩", "🔥", true],
    ];
    spec.forEach(([from, to, isBorder]) => {
      it(`${from}  should ${isBorder ? "" : "NOT "}border ${to}`, () => {
        assert.equal(
          maps.isBorder(adjacency, from, to),
          isBorder,
          `${[from, to].join(" ->")} expected to border: ${isBorder}`
        );
      });
    });
  });

  describe("Miño", () => {
    const [lands, adjacency] = maps.loadMap("Miño");
    const all = ["🍋", "💩", "🐙", "🔥", "💰"];
    const spec: [string, string[]][] = [
      ["🍋", ["💩", "🐙", "🔥"]],
      ["💩", ["🍋", "🔥"]],
      ["🔥", ["🍋", "💩", "🐙", "💰"]],
      ["💰", ["🔥", "🐙"]],
      ["🐙", ["🍋", "🔥", "💰"]],
    ];
    spec.forEach(([from, tos]) => {
      tos.forEach(to => {
        it(`${from} should border ${to}`, () => {
          assert.equal(
            maps.isBorder(adjacency, from, to),
            true,
            `${[from, to].join(" ->")} expected to border`
          );
        });
      });
      R.without(tos, all).forEach(to => {
        it(`${from} should NOT border ${to}`, () => {
          assert.equal(
            maps.isBorder(adjacency, from, to),
            false,
            `${[from, to].join(" ->")} expected to not border`
          );
        });
      });
    });
  });

  describe("Connected lands count", () => {
    it("should count simple relation", () => {
      const redEmojis = ["🍋", "💰", "🐸", "🐵"];
      const [lands, adjacency] = maps.loadMap("Melchor");

      assert.equal(
        maps.countConnectedLands({
          lands: lands.map(land =>
            Object.assign(land, {
              color: R.contains(land.emoji, redEmojis) ? 1 : -1,
            })
          ),
          adjacency,
        })(1),
        2
      );
    });
    it("should count complex relation", () => {
      const redEmojis = ["🍋", "💰", "🐸", "🐵", "🥑", "👑", "🌙", "🌵", "🐙"];
      const colorRed = 1;
      const [lands, adjacency] = maps.loadMap("Melchor");

      assert.equal(
        maps.countConnectedLands({
          lands: lands.map(land =>
            Object.assign(land, {
              color: R.contains(land.emoji, redEmojis) ? 1 : -1,
            })
          ),
          adjacency,
        })(colorRed),
        5
      );
    });

    it("should count simple big relation", () => {
      const redEmojis = [
        "🍋",
        "💰",
        "🐸",
        "🐵",
        "🥑",
        "👑",
        "🌙",
        "🌵",
        "🐙",
        "🍺",
      ];
      const [lands, adjacency] = maps.loadMap("Melchor");

      assert.equal(
        maps.countConnectedLands({
          lands: lands.map(land =>
            Object.assign(land, {
              color: R.contains(land.emoji, redEmojis) ? 1 : -1,
            })
          ),
          adjacency,
        })(1),
        9
      );
    });

    it("should count two equals relations", () => {
      const redEmojis = ["🍋", "💰", "🐸", "🐵", "🥑"];
      const [lands, adjacency] = maps.loadMap("Melchor");
      assert.equal(
        maps.countConnectedLands({
          lands: lands.map(land =>
            Object.assign(land, {
              color: R.contains(land.emoji, redEmojis) ? 1 : -1,
            })
          ),
          adjacency,
        })(1),
        2
      );
    });
  });

  describe("land order should be fixed for e2e determinism", () => {
    const orders = {
      Planeta:
        "🐵🐧👀🍷👙🍀🍌🍏🍉🥑😺🛸💰🍒🍺👍🍋🐙🎩🌵🐸🏰👻💊🔥🌙🐰🎵💀💎🌴💣💥💋💃💧🍩🗿🐟🌎🤠👑",
      Serrano: "🐙🐸🍷💰🏰💀💎🎩🌙💊👑🍒👙🔥🍋🌴💃",
      DeLucía: "💰😺🐵👻🐙🥑💎🐸💧💊🌴🌙🍒🎩🍉🍩🍌🍏🌵💋👙🍀💣🌎💀",
      Melchor: "🔥😺🍋🐵💰👻🐙🥑🐸🍺🌵👑🌙",
      Miño: "🍋💩🐙🔥💰",
      Sabicas:
        "🎩🍉🥑🍏🎵👀👙🍺🐵🐟🐧👍🐸😺🏰💰🐰🍷🍋👻🐙🍩🌴🔥🌙💥💋🌎💀💣💊💧",
    };
    config.tables
      .map(t => t.mapName)
      .forEach(mapName => {
        const [lands, _] = maps.loadMap(mapName);
        it(`${mapName} should be fixed`, () => {
          assert.equal(lands.map(l => l.emoji).join(""), orders[mapName]);
        });
      });
  });
});
