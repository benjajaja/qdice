const { defaults: tsjPreset } = require('ts-jest/presets');

module.exports = {
  preset: 'jest-puppeteer',
  testMatch: [
    "**/*.test.ts",
  ],
  globals: {
    "ts-jest": {
      tsConfig: 'tsconfig.json',
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
