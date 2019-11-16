import expectPuppeteer from 'expect-puppeteer';
import got from 'got';

let TEST_TIMEOUT = 10000;
// TEST_TIMEOUT = 1000000;
global.TEST_URL = 'http://localhost';

(expectPuppeteer as any).setDefaultOptions({timeout: TEST_TIMEOUT - 100});
jest.setTimeout(TEST_TIMEOUT);

global.testId = (id: string) => `[data-test-id="${id}"]`;
global.testValue = (id: string, key: string, value: string) =>
  `[data-test-id="${id}"][data-test-${key}="${value}"]`;

beforeEach(async () => {
  await got('http://localhost/api/e2e');
  await page.evaluateOnNewDocument(() => localStorage.clear());
  await page.goto(TEST_URL);
  await expect(page).toMatchElement(testId('connection-status'), {
    text: 'Online',
  });
});
