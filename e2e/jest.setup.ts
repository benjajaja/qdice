import { setDefaultOptions } from 'expect-puppeteer';
import * as got from "got";

let TEST_TIMEOUT = 1000;
TEST_TIMEOUT = 1000000;
global.TEST_URL = "http://localhost:5000";

setDefaultOptions({ timeout: TEST_TIMEOUT })
jest.setTimeout(TEST_TIMEOUT);

global.testId = (id: string) => `[data-test-id="${id}"]`;

beforeEach(async () => {
  await got("http://localhost:5001/api/e2e");
  await page.evaluateOnNewDocument(() => localStorage.clear());
  await page.goto(TEST_URL);
  await expect(page).toMatchElement(testId("connection-status"), { text: "Online" });
});

