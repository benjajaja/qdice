import { setup } from 'jest-environment-puppeteer';

module.exports = async function globalSetup(globalConfig) {
  await setup(globalConfig);
};
