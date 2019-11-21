import puppeteer, {Page} from 'puppeteer';
import {launch} from './jest-puppeteer.config.js';

const attack = async (page: Page, from: string, to: string, name: string) => {
  await expect(page).toMatchElement(
    '[data-test-id="logline-turn"]:nth-child(1)',
    {
      text: new RegExp(`^${name}'s turn`),
    },
  );
  console.log(`${name}'s turn`);
  await expect(page).toClick(testId(from));
  console.log(`clicked from ${from}`);
  // jestPuppeteer.debug();
  await expect(page).toMatchElement(testValue(from, 'selected', 'true'));
  await expect(page).toClick(testId(to));
  console.log(`clicked to ${to}`);
  await expect(page).toMatchElement(testValue(to, 'selected', 'true'));
  await expect(page).toMatchElement(
    '[data-test-id="logline-roll"]:nth-child(1)',
    {
      text: new RegExp(`^${name} (won|lost)`),
    },
  );
};

describe('A full game', () => {
  test('should play a full game', async () => {
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

    await expect(page2).toClick(testId('button-seat'), {text: 'Join'});
    await expect(page2).toMatchElement(testId('login-dialog'));

    await expect(page2).toFill(testId('login-input'), 'B');
    await expect(page2).toClick(testId('login-login'));

    await expect(page2).not.toMatchElement(testId('login-dialog'));

    await expect(page2).toMatchElement(testId('player-name-1'), {text: 'B'});

    await expect(page2).toClick(testId('check-ready'));

    await expect(page).toMatchElement(testId('game-status'), {text: 'playing'});

    await attack(page, 'land-🍷', 'land-🏰', 'A');
    await expect(page).toClick(testId('button-seat'), {text: 'End turn'});

    await attack(page2, 'land-💊', 'land-🌙', 'B');
    await expect(page2).toClick(testId('button-seat'), {text: 'End turn'});

    await attack(page, 'land-🏰', 'land-🌙', 'A');
    await expect(page).toClick(testId('button-seat'), {text: 'End turn'});

    await attack(page2, 'land-💊', 'land-🌙', 'B');
    await expect(page2).toClick(testId('button-seat'), {text: 'End turn'});

    await attack(page, 'land-🌙', 'land-💊', 'A');

    expect(
      await page.evaluate(
        el => el.innerText,
        await page.$(testId('logline-elimination')),
      ),
    ).toMatch(
      /^🏆 A won the game! with \d+ ✪ \(Last standing player after 5 turns\)/,
    );

    // expect(
    // await page.evaluate(
    // el => el.innerText,
    // await page.$(testId('logline-elimination'))),
    // ),
    // ).toMatch(/^☠ A finished 2nd/);

    await browser2.close();
  }, 30000);
});
