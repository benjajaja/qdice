const { defaults: tsjPreset } = require('ts-jest/presets');

module.exports = {
  timeout: 100000,
  preset: 'jest-puppeteer',
  testMatch: [
    "**/*.test.ts",
  ],
  globals: {
    "ts-jest": {
      tsConfig: 'tsconfig.test.json',
      diagnostics: {
        warnOnly: true,
      },
    },
  },
  transform: {
    ...tsjPreset.transform,
  },
  setupFilesAfterEnv: ['<rootDir>/jest.setup.ts'],
  globalSetup: './jest.global-setup.ts',
};
