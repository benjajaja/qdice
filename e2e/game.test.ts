import puppeteer, { Page } from "puppeteer";
import { launch } from "./jest-puppeteer.config.js";
import { setInterval, clearInterval } from "timers";

const hisTurn = async (page: Page, name: string) =>
  await expect(page).toMatchElement(
    '[data-test-id="logline-turn"]:nth-last-child(1)',
    {
      text: new RegExp(`^${name}'s turn`),
    }
  );

const attack = async (page: Page, from: string, to: string, name: string) => {
  console.log(`player "${name}" attack from ${from} to ${to}`);
  const logLineCount = (await page.$$(testId("logline-roll"))).length;

  await expect(page).toClick(testId(from));
  await expect(page).toMatchElement(testValue(from, "selected", "true"));
  await expect(page).toClick(testId(to));
  await expect(page).toMatchElement(testValue(to, "selected", "true"));

  const lines = await page.$eval("#gameLog-Lagos", container => {
    return new Promise<string[]>(resolve => {
      const observer = new MutationObserver(() => {
        observer.disconnect();
        resolve(
          Array.prototype.slice
            .call(container.querySelectorAll('[data-test-id="logline-roll"]'))
            .map((line: Element) => line.textContent ?? "")
        );
      });
      observer.observe(container, {
        attributes: false,
        childList: true,
        characterData: false,
        subtree: false,
      });
    });
  });

  const newLines = lines.slice(logLineCount);

  expect(
    newLines.some(line =>
      line ? new RegExp(`^${name} (won over|lost against)`).test(line) : false
    )
  ).toBe(true);

  return newLines;
};

describe("A full game", () => {
  let gameId: string | undefined;
  test("should play a full game", async () => {
    await expect(page).toMatchElement(testId("table-games-link"), {
      text: "Planeta",
    });
    await expect(page).toClick(testId("go-to-table-Lagos"));

    await expect(page).toClick(testId("button-seat"));
    await expect(page).toMatchElement(testId("login-dialog"));

    await expect(page).toFill(testId("login-input"), "A");
    await expect(page).toClick(testId("login-login"), { text: "Play" });

    await expect(page).not.toMatchElement(testId("login-dialog"));

    await expect(page).toMatchElement(testId("player-name-0"), { text: "A" });

    await expect(page).toClick(testId("check-ready"));
    console.log("Player A ready");

    const browser2 = await puppeteer.launch({
      ...launch /*, headless: false*/,
    });
    const page2 = await browser2.newPage();
    await page2.evaluateOnNewDocument(() => localStorage.clear());
    await page2.goto(`${TEST_URL}/Lagos`);
    await expect(page2).toMatchElement(testId("connection-status"), {
      text: "Online on Lagos",
    });
    await expect(page2).toMatchElement(testId("table-games-link"), {
      text: "Lagos",
    });

    await expect(page2).toClick(testId("button-seat"));
    await expect(page2).toMatchElement(testId("login-dialog"));

    await expect(page2).toFill(testId("login-input"), "B");
    await expect(page2).toClick(testId("login-login"));

    await expect(page2).not.toMatchElement(testId("login-dialog"));

    await expect(page2).toMatchElement(testId("player-name-1"), { text: "B" });
    console.log("Player B is in game");

    await expect(page2).not.toMatchElement(testId("game-round"));

    await expect(page2).toClick(testId("check-ready"));

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
    await attack(page, "land-🐵", "land-😺", "A");
    await attack(page, "land-😺", "land-🐙", "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page2, "B");
    await attack(page2, "land-🌵", "land-🍩", "B");
    await attack(page2, "land-🍩", "land-🌙", "B");
    await attack(page2, "land-🌙", "land-🐸", "B");
    await expect(page2).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page, "A");
    await attack(page, "land-🐙", "land-💎", "A");
    await attack(page, "land-💎", "land-🐸", "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page2, "B");
    await attack(page2, "land-🌙", "land-🐸", "B");
    await expect(page2).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page, "A");
    await attack(page, "land-💎", "land-🐸", "A");
    await attack(page, "land-🐸", "land-🌙", "A");
    await attack(page, "land-🐙", "land-💰", "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page2, "B");
    await expect(page2).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page, "A");
    await attack(page, "land-🌙", "land-🍩", "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page2, "B");
    await expect(page2).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page, "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page2, "B");
    await expect(page2).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page, "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page2, "B");
    await expect(page2).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page, "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page2, "B");
    await expect(page2).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page, "A");
    await attack(page, "land-🍩", "land-🌵", "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    await expect(page).toMatchElement(
      `${testId("logline-elimination")}:nth-last-child(2)`,
      {
        text: /^☠ B finished 2nd with -?\d+ ✪ \(Killed by A for \d+✪\)/,
      }
    );
    await expect(page).toMatchElement(
      `${testId("logline-elimination")}:nth-last-child(1)`,
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

    await expect(page).toMatchElement(testId("game-event"));

    await expect(page).toClick(testId("replayer-goto-end"));

    await expect(page).toMatchElement(testId("game-event"), {
      text: /A won the game after 15 rounds/,
    });
    const count = (await page.$$(testId("game-event"))).length;
    expect(count).toBe(28);
  });
});
