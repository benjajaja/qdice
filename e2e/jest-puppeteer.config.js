module.exports = {
  launch: {
    dumpio: false,
    headless: true,
    slowMo: 0,
    args: ['--disable-infobars', '--no-sandbox', '--disable-setuid-sandbox'],
    devtools: true,
    defaultViewport: null,
  },
  browserContext: 'default',
};
