import { Page } from "puppeteer";

declare global {
  var page: Page;
  var localStorage: any; // for `page.eval(() => ... )` that is run in browser
  var jestPuppeteer: { debug: () => void }; // pause browser, needs large timeout
}

