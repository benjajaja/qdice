import * as puppeteer from "puppeteer";

describe('A full game', () => {
  it('should play a full game', async () => {
    await expect(page).toClick(".edButton.edGameHeader__button", { text: "Join" });
    await expect(page).toMatchElement(".edLoginDialog", { timeout: 3000 });

    await expect(page).toFill(".edLoginDialog form input", "A");
    await expect(page).toClick(".edLoginDialog__buttons button:nth-child(2)");


    await expect(page).not.toMatchElement(".edLoginDialog");

    const browser2 = await puppeteer.launch({
      headless: true,
      slowMo: 0,
      args: ['--disable-infobars'],
      timeout: 500,
      defaultViewport: null,
    })
    const page2 = await browser2.newPage()
    await page2.evaluateOnNewDocument(() => localStorage.clear());
    await page2.goto(TEST_URL);
    await expect(page2).toMatchElement(testId("connection-status"), { text: "Online" });

    await expect(page2).toClick(".edButton.edGameHeader__button", { text: "Join" });
    await expect(page2).toMatchElement(".edLoginDialog");

    await expect(page2).toFill(".edLoginDialog form input", "B");
    await expect(page2).toClick(".edLoginDialog__buttons button:nth-child(2)");

    await expect(page).toMatchElement(testId("game-status"), { text: "playing" });
    // await jestPuppeteer.debug();

    await browser2.close()
  });

});


