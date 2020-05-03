import * as assert from "assert";
import * as R from "ramda";
import * as maps from "../maps";
import * as config from "../tables.config";

describe("Maps", () => {
  describe("Loading", () => {
    it("should load a map", () => {
      const [lands, _] = maps.loadMap("Planeta");
      assert.equal(lands.length, 42);
    });
  });

  describe("Borders of Serrano", () => {
    const [lands, adjacency] = maps.loadMap("Serrano");
    const spec: [string, string, boolean][] = [
      ["🏰", "💰", false],
      ["💎", "🍒", true],
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

  describe("land order should be fixed for e2e determinism", () => {
    const orders = {
      Planeta:
        "🐵🐧👀🍷👙🍀🍌🍏🍉🥑😺🛸💰🍒🍺🎩👍🍋🐙🌵🐸🏰👻💊🔥🌙🐰🎵💀💎🌴💣💥💋💃💧🍩🗿🐟🌎🤠👑",
      Serrano: "🐙🐸🍷💰🏰💀💎🎩🌙💊👑🍒👙🔥🍋🌴💃",
      DeLucía: "💰😺🐵👻🐙🥑💎🐸💧💊🌴🌙🍒🎩🍉🍩🍌🍏🌵💋👙🍀💣🌎💀",
      Sabicas:
        "🎩🍉🥑🍏🎵👀👙🍺🐵🐟🐧👍🐸😺🏰💰🐰🍷🍋👻🐙🍩🌴🔥🌙💥💋🌎💀💣💊💧",
    };
    config.tables
      .map(t => t.mapName)
      .forEach(mapName => {
        const [lands, _] = maps.loadMap(mapName);
        if (orders[mapName]) {
          it(`${mapName} should be fixed`, () => {
            assert.equal(lands.map(l => l.emoji).join(""), orders[mapName]);
          });
        }
      });
  });
});
