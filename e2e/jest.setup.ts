import { setDefaultOptions } from 'expect-puppeteer';

let TEST_TIMEOUT = 1000;
// TEST_TIMEOUT = 100000;

setDefaultOptions({ timeout: TEST_TIMEOUT })
jest.setTimeout(TEST_TIMEOUT);

