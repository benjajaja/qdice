module.exports = {
  launch: {
    dumpio: false,
    headless: true,
    slowMo: 0,
    args: ["--disable-infobars", "--no-sandbox", "--disable-setuid-sandbox"],
    devtools: true,
    defaultViewport: {
      width: 400,
      height: 600,
      isMobile: true,
      hasTouch: true,
      isLandscape: false,
    },
  },
  browserContext: "default",
};
