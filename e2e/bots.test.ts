import puppeteer, { Page, ElementHandle } from "puppeteer";
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

  const lines = await page.$eval("#gameLog-España", container => {
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

describe("A game with bots", () => {
  test("should play a full game", async () => {
    await expect(page).toClick(testId("go-to-table-España"));

    await expect(page).toClick(testId("button-seat"));
    await expect(page).toMatchElement(testId("login-dialog"));

    await expect(page).toFill(testId("login-input"), "A");
    await expect(page).toClick(testId("login-login"), { text: "Play" });

    await expect(page).not.toMatchElement(testId("login-dialog"));

    await expect(page).toMatchElement(testId("player-name-0"), { text: "A" });

    await expect(page).toClick(testId("check-ready"));

    await expect(page).toMatchElement(testId("game-status"), {
      text: "playing",
      timeout: 40000,
    });

    await hisTurn(page, "A");
    await attack(page, "land-💀", "land-🌙", "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    await hisTurn(page, "A");
    await attack(page, "land-🌙", "land-👑", "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    // await hisTurn(page, "A");
    // await attack(page, "land-🍷", "land-🐸", "A");
    // await attack(page, "land-🏰", "land-🎩", "A");
    // await expect(page).toClick(testId("check-flag") [>, { text: "Flag 2nd" }<]);
    // await attack(page, "land-🐸", "land-🐙", "A");
    // await attack(page, "land-🎩", "land-👙", "A");

    await expect(page).toMatchElement(
      `${testId("logline-elimination")}:nth-last-child(1)`,
      {
        text: /^☠ A finished 4th with -?\d+ ✪ \(Killed by Cohete for \d+✪\)/,
      }
    );
    // await expect(page).toMatchElement(
    // `${testId("logline-elimination")}:nth-child(3)`,
    // {
    // text: /^🏳 Mono finished 3rd with -?\d+ ✪ \(Flagged for 3rd\)/,
    // }
    // );
    // console.log("ok 3");
    // await expect(page).toMatchElement(
    // `${testId("logline-elimination")}:nth-child(2)`,
    // {
    // text: /^🏳 Cohete finished 2nd with -?\d+ ✪ \(Flagged for 2nd\)/,
    // }
    // );
    // console.log("ok 2");
    // await expect(page).toMatchElement(
    // `${testId("logline-elimination")}:nth-child(1)`,
    // {
    // text: /^🏆 Cuqui won the game! with \d+ ✪ \(Last standing player after \d+ turns\)/,
    // }
    // );
  }, 300000);
});
