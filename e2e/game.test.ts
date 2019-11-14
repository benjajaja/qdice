import puppeteer, { Page } from "puppeteer";

const attack = async (page: Page, from: string, to: string, name: string) => {
  await expect(page).toMatchElement("[data-test-id=\"logline-turn\"]:nth-child(1)", {
    text: new RegExp(`^${name}'s turn`),
  });
  await expect(page).toClick(testId(from));
  await expect(page).toClick(testId(to));
  await expect(page).toMatchElement("[data-test-id=\"logline-roll\"]:nth-child(1)", {
    text: new RegExp(`^${name} (won|lost)`),
  });
};

describe('A full game', () => {
  test('should play a full game', async () => {
    await expect(page).toClick(testId("button-seat"));
    await expect(page).toMatchElement(testId("login-dialog"));

    await expect(page).toFill(testId("login-input"), "A");
    await expect(page).toClick(testId("login-login"), { text: "Play" });

    await expect(page).not.toMatchElement(testId("login-dialog"));

    await expect(page).toMatchElement(testId("player-name-0"), { text: "A" });

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

    await expect(page2).toClick(testId("button-seat"), { text: "Join" });
    await expect(page2).toMatchElement(testId("login-dialog"));

    await expect(page2).toFill(testId("login-input"), "B");
    await expect(page2).toClick(testId("login-login"));

    await expect(page2).not.toMatchElement(testId("login-dialog"));

    await expect(page2).toMatchElement(testId("player-name-1"), { text: "B" });


    await expect(page).toMatchElement(testId("game-status"), { text: "playing" });

    await attack(page, "land-🍷", "land-💰", "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    await attack(page2, "land-💊", "land-🌙", "B");
    await expect(page2).toClick(testId("button-seat"), { text: "End turn" });

    await attack(page, "land-🍷", "land-💰", "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    await attack(page2, "land-🌙", "land-🏰", "B");
    await expect(page2).toClick(testId("button-seat"), { text: "End turn" });

    await attack(page, "land-🍷", "land-💰", "A");
    await expect(page).toClick(testId("button-seat"), { text: "End turn" });

    await attack(page2, "land-🏰", "land-🍷", "B");

    const eliminations = await page.mainFrame().waitForSelector(testId("logline-elimination"));
    console.log(eliminations.toString());
      // text: new RegExp("^☠ A finished 2nd"),
    // });
    // await expect(page).toMatchElement("[data-test-id=\"logline-elimination\"]:nth-child(1)", {
      // text: new RegExp("^🏆 B won the game!"),
    // });


    await browser2.close()
  }, 300000);

});


