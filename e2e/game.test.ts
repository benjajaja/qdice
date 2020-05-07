import * as R from "ramda";
import { joinN, nextTurn, hisTurn, attack } from "./game-helpers";

describe("A full game", () => {
  test("quick flag game", async () => {
    const [{ browser: browser2, page: page2 }] = await joinN("Lagos", "A", "B");

    await expect(page).toMatchElement(testId("game-round"), {
      text: "round 1",
    });

    for (let _ in R.range(0, 5)) {
      await hisTurn(page, "A");
      await nextTurn(page);
      await hisTurn(page2, "B");
      await nextTurn(page2);
    }
    await nextTurn(page);

    await expect(page).toMatchElement(testId("game-round"), {
      text: "round 6",
    });

    await expect(page2).toClick(testId("check-flag"));

    await expect(page).toMatchElement(
      `${testId("logline-elimination")}:nth-last-child(3)`,
      {
        text: /^🏳 B finished 2nd with -?\d+ ✪ \(Flagged for 2nd\)/,
      }
    );
    await expect(page).toMatchElement(
      `${testId("logline-elimination")}:nth-last-child(2)`,
      {
        text: /^🏆 A won the game! with \d+ ✪ \(Last standing player after \d+ turns\)/,
      }
    );

    console.log("full game flagging test finished");
    await browser2.close();
  });

  let gameId: string | undefined;
  test("should play a full game", async () => {
    const [{ browser: browser2, page: page2 }] = await joinN("Lagos", "A", "B");

    await expect(page).toMatchElement(testId("game-round"), {
      text: "round 1",
    });

    console.log("Game has started round 1");

    await expect(page).toMatchElement(testId("current-game-id"));
    const text = await (
      await expect(page).toMatchElement(testId("current-game-id"))
    ).evaluate(element => element.textContent);
    gameId = text?.match(/game #(\d+)/)?.[1];
    expect(gameId).not.toBeUndefined();

    await hisTurn(page, "A");
    await attack(page, "land-🌎", "land-🍀", "A");
    await attack(page, "land-🍀", "land-🌵", "A");
    await attack(page, "land-🌵", "land-🍩", "A");
    await nextTurn(page);

    await hisTurn(page2, "B");
    await attack(page2, "land-💎", "land-🐸", "B");
    await attack(page2, "land-🐸", "land-🌙", "B");
    await attack(page2, "land-🌙", "land-🍩", "B");
    await nextTurn(page2);

    await hisTurn(page, "A");
    await attack(page, "land-🍩", "land-🌙", "A");
    await attack(page, "land-🌙", "land-🐸", "A");
    await nextTurn(page);

    await hisTurn(page2, "B");
    // await attack(page2, "land-💎", "land-🐸", "B");
    await nextTurn(page2);

    await hisTurn(page, "A");
    await attack(page, "land-🐸", "land-💎", "A");
    // await nextTurn(page);

    console.log("game should have finished");

    await expect(page).toMatchElement(
      `${testId("logline-elimination")}:nth-last-child(3)`,
      {
        text: /^☠ B finished 2nd with -?\d+ ✪ \(Killed by A for \d+✪\)/,
      }
    );
    await expect(page).toMatchElement(
      `${testId("logline-elimination")}:nth-last-child(2)`,
      {
        text: /^🏆 A won the game! with \d+ ✪ \(Last standing player after \d+ turns\)/,
      }
    );

    console.log("full game test finished");
    await browser2.close();
  }, 300000);

  test("should show game ledger of previous test's game", async () => {
    expect(gameId).not.toBeUndefined();
    await expect(page).toClick(testId("go-to-table-Lagos"));
    await expect(page).toClick(testId("table-games-link"));
    await expect(page).toClick(testId("game-entry-" + gameId));

    await expect(page).toMatchElement(testId("player-name-0"), { text: "A" });
    await expect(page).toMatchElement(testId("player-name-1"), { text: "B" });

    await expect(page).toClick(testId("replayer-goto-end"));

    await expect(page).not.toMatchElement(testId("player-name-0"), {
      text: "B",
    });
    await expect(page).toMatchElement(testId("player-name-0"), { text: "A" });

    await expect(page).toMatchElement(testId("game-event"), {
      text: /A won the game after 5 turns/,
    });
    const count = (await page.$$(testId("game-event"))).length;
    expect(count).toBe(24);
  });
});
