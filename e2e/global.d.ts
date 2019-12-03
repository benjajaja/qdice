import { Page } from "puppeteer";

declare global {
  var page: Page;
  var localStorage: any; // for `page.eval(() => ... )` that is run in browser
  var jestPuppeteer: { debug: () => void }; // pause browser, needs large timeout
  var testId: (id: string) => string;
  var testValue: (id: string, key: string, value: string) => string;
  var TEST_URL: string;
}

declare global {
  namespace NodeJS {
    interface Global {
      testId: (id: string) => string;
      testValue: (id: string, key: string, value: string) => string;
      TEST_URL: string;
    }
  }
}
