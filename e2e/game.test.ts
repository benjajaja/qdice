import puppeteer, {Page} from 'puppeteer';
import {launch} from './jest-puppeteer.config.js';
import {setInterval, clearInterval} from 'timers';

const hisTurn = async (page: Page, name: string) =>
  await expect(page).toMatchElement(
    '[data-test-id="logline-turn"]:nth-child(1)',
    {
      text: new RegExp(`^${name}'s turn`),
    },
  );

const attack = async (page: Page, from: string, to: string, name: string) => {
  console.log(`player "${name}" attack from ${from} to ${to}`);
  const latestLog = await page.evaluate(
    () =>
      document.querySelector('[data-test-id="logline-roll"]:nth-child(1)')
        ?.textContent,
  );
  console.log(latestLog);

  await expect(page).toClick(testId(from));
  await expect(page).toMatchElement(testValue(from, 'selected', 'true'));
  await expect(page).toClick(testId(to));
  await expect(page).toMatchElement(testValue(to, 'selected', 'true'));

  // must wait for a new logline if there were previous
  if (latestLog !== undefined) {
    await new Promise(resolve => {
      const interval = setInterval(async () => {
        if (
          (await page.evaluate(
            () =>
              document.querySelector(
                '[data-test-id="logline-roll"]:nth-child(1)',
              )?.textContent,
          )) !== latestLog
        ) {
          clearInterval(interval);
          resolve();
        }
      }, 1);
    });
  }
  // but also ensure that is was our roll
  await expect(page).toMatchElement(
    '[data-test-id="logline-roll"]:nth-child(1)',
    {
      text: new RegExp(`^${name} (won over|lost against)`),
    },
  );
};

describe('A full game', () => {
  test('should play a full game', async () => {
    await expect(page).toClick(testId('go-to-table-Melchor'));

    await expect(page).toClick(testId('button-seat'));
    await expect(page).toMatchElement(testId('login-dialog'));

    await expect(page).toFill(testId('login-input'), 'A');
    await expect(page).toClick(testId('login-login'), {text: 'Play'});

    await expect(page).not.toMatchElement(testId('login-dialog'));

    await expect(page).toMatchElement(testId('player-name-0'), {text: 'A'});

    await expect(page).toClick(testId('check-ready'));

    const browser2 = await puppeteer.launch({...launch, headless: true});
    const page2 = await browser2.newPage();
    await page2.evaluateOnNewDocument(() => localStorage.clear());
    await page2.goto(TEST_URL);
    await expect(page2).toMatchElement(testId('connection-status'), {
      text: 'Online',
    });

    await expect(page2).toClick(testId('go-to-table-Melchor'));
    await expect(page2).toClick(testId('button-seat'), {text: 'Join'});
    await expect(page2).toMatchElement(testId('login-dialog'));

    await expect(page2).toFill(testId('login-input'), 'B');
    await expect(page2).toClick(testId('login-login'));

    await expect(page2).not.toMatchElement(testId('login-dialog'));

    await expect(page2).toMatchElement(testId('player-name-1'), {text: 'B'});

    await expect(page2).toClick(testId('check-ready'));

    await expect(page).toMatchElement(testId('game-status'), {text: 'playing'});

    await hisTurn(page, 'A');
    await attack(page, 'land-🥑', 'land-🐵', 'A');
    await attack(page, 'land-🐵', 'land-🍺', 'A');
    await expect(page).toClick(testId('button-seat'), {text: 'End turn'});

    await hisTurn(page2, 'B');
    await attack(page2, 'land-🐸', 'land-🍺', 'B');
    await expect(page2).toClick(testId('button-seat'), {text: 'End turn'});

    await hisTurn(page, 'A');
    await attack(page, 'land-🍺', 'land-🐸', 'A');
    await expect(page).toClick(testId('button-seat'), {text: 'End turn'});

    await hisTurn(page2, 'B');
    await expect(page2).toClick(testId('button-seat'), {text: 'End turn'});

    await hisTurn(page, 'A');
    await expect(page).toClick(testId('button-seat'), {text: 'End turn'});

    await hisTurn(page2, 'B');
    await attack(page2, 'land-🐸', 'land-🍺', 'B');
    await expect(page2).toClick(testId('button-seat'), {text: 'End turn'});

    await hisTurn(page, 'A');
    await attack(page, 'land-🍺', 'land-🐸', 'A');

    expect(
      await page.evaluate(
        el => el.innerText,
        await page.$(testId('logline-elimination')),
      ),
    ).toMatch(
      /^🏆 A won the game! with \d+ ✪ \(Last standing player after \d+ turns\)/,
    );

    await browser2.close();
    // expect(
    // await page.evaluate(
    // el => el.innerText,
    // await page.$(testId('logline-elimination'))),
    // ),
    // ).toMatch(/^☠ A finished 2nd/);
  }, 300000);
});
