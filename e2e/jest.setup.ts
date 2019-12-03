import expectPuppeteer from "expect-puppeteer";
import got from "got";

global.TEST_URL = process.env.E2E_URL || "http://localhost";
const E2E_API_RESET_URL =
  process.env.E2E_API_RESET_URL || `${TEST_URL}/api/e2e`;

let TEST_TIMEOUT = 10000;
// TEST_TIMEOUT = 1000000;

(expectPuppeteer as any).setDefaultOptions({
  /*timeout: TEST_TIMEOUT - 100*/
});
jest.setTimeout(TEST_TIMEOUT);

global.testId = (id: string) => `[data-test-id="${id}"]`;
global.testValue = (id: string, key: string, value: string) =>
  `[data-test-id="${id}"][data-test-${key}="${value}"]`;

beforeEach(async () => {
  await got(E2E_API_RESET_URL);
  await page.evaluateOnNewDocument(() => localStorage.clear());
  page.on("console", consoleObj => console.log("page:", consoleObj.text()));
  await page.goto(TEST_URL, { waitUntil: "networkidle2" });
  // const base64 = await page.screenshot({
  // fullPage: true,
  // encoding: 'base64',
  // });
  // console.log(`screenshot: data:image/png;base64,${base64}`);
  await expect(page).toMatchElement(testId("connection-status"), {
    text: "Online",
  });
});
