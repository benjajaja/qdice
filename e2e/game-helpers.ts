import puppeteer, { Page, Browser } from "puppeteer";
import { launch } from "./jest-puppeteer.config.js";

export const hisTurn = async (page: Page, name: string) => {
  await expect(page).toMatchElement(
    '[data-test-id="logline-turn"]:nth-last-child(1)',
    {
      text: new RegExp(`^${name}'s turn`),
    }
  );
};

export const nextTurn = async (page: Page) => {
  await expect(page).toClick(testId("button-seat"), { text: "End turn" });
};

export const attack = async (
  page: Page,
  from: string,
  to: string,
  name: string
) => {
  console.log(`player "${name}" attack from ${from} to ${to}`);
  const logLineCount = (await page.$$(testId("logline-roll"))).length;

  await expect(page).toClick(testId(from));
  await expect(page).toMatchElement(testValue(from, "selected", "true"));

  const [_, __, lines] = await Promise.all([
    expect(page).toClick(testId(to)),
    expect(page).toMatchElement(testValue(to, "selected", "true")),
    page.$eval("#gameLog-Lagos", container => {
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
    }),
  ]);

  const newLines = lines.slice(logLineCount);

  expect(
    newLines.some(line =>
      line ? new RegExp(`^${name} (won over|lost against)`).test(line) : false
    )
  ).toBe(true);

  return newLines;
};

export const join = async (
  page: Page,
  tableTag: string,
  name: string,
  index = "0"
) => {
  await expect(page).toClick(testId("go-to-table-" + tableTag));

  await expect(page).toClick(testId("button-seat"));
  await expect(page).toMatchElement(testId("login-dialog"));

  await expect(page).toFill(testId("login-input"), name);
  await expect(page).toClick(testId("login-login"), { text: "Play" });

  await expect(page).not.toMatchElement(testId("login-dialog"));

  console.log(`Player ${name}/${index} joined?`);
  await expect(page).toMatchElement(testId(`player-name-${index}`), {
    text: name,
  });

  await expect(page).toClick(testId("check-ready"));
  console.log(`Player ${name} ready`);
  return { browser, page };
};

export const joinNewBrowser = async (
  tableTag: string,
  name: string,
  index: string
) => {
  console.log("opening a new browser");
  const browser2 = await puppeteer.launch({
    ...launch /*, headless: false*/,
  });
  const page2 = await browser2.newPage();
  await page2.evaluateOnNewDocument(() => localStorage.clear());
  await page2.goto(`${TEST_URL}/${tableTag}`);
  await expect(page2).toMatchElement(testId("connection-status"), {
    text: `Online on ${tableTag}`,
  });
  await join(page2, tableTag, name, index);
  console.log(`Player ${name} is in game`);
  return { browser: browser2, page: page2 };
};

export const joinN = async (
  tableTag: string,
  mainName: string,
  ...names: string[]
) => {
  console.log(`Setting up game with ${mainName}, ${names}`);
  await join(page, tableTag, mainName);
  const refs: { browser: Browser; page: Page }[] = [];
  for (let i in names) {
    refs.push(
      await joinNewBrowser(tableTag, names[i], (parseInt(i) + 1).toString())
    );
  }
  return refs;
};
