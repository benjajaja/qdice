import * as puppeteer from "puppeteer";
import * as got from "got";

beforeEach(async () => {
  await got("http://localhost/api/e2e");
  await sleep(100);
  await page.goto('http://localhost');
  await page.evaluate(() => {
    localStorage.clear();
  });
  await sleep(100);
});
afterEach(async () => {
  await got("http://localhost/api/e2e");
});

describe('Home', () => {
  it('should set title', async () => {
    const title = await page.title();
    expect(title).toBe("Qdice.wtf");
  });


  it('should display "Table..." text on page', async () => {
    await expect(page).toMatch('Table España')
  });

  it('should display "join" button on page', async () => {
    await expect(page).toMatchElement(".edButton.edGameHeader__button", { text: "Join" })
  });

  it('should display and close the login dialog', async () => {
    await expect(page).toClick(".edButton.edGameHeader__button", { text: "Join" });
    await expect(page).toMatchElement(".edLoginDialog");

    await expect(page).toMatchElement(".edLoginDialog__buttons button", { text: "Close" });
    await expect(page).toClick(".edLoginDialog__buttons button:nth-child(1)");

    await expect(page).not.toMatchElement(".edLoginDialog", { timeout: 2000 });
  });

});

describe('Join', () => {
  it('should join and leave a game', async () => {
    await expect(page).toClick(".edButton.edGameHeader__button", { text: "Join" });
    await expect(page).toMatchElement(".edLoginDialog");

    await expect(page).toFill(".edLoginDialog form input", "puppet");
    await expect(page).toClick(".edLoginDialog__buttons button:nth-child(2)");

    await expect(page).not.toMatchElement(".edLoginDialog");
    await expect(page).toMatchElement(".edPlayerChip__name", { text: "puppet" });

    await expect(page).toClick(".edButton.edGameHeader__button", { text: "Leave" });
    await expect(page).not.toMatchElement(".edPlayerChip__name", { text: "puppet" });
  });

});

describe('Two players', () => {
  it.only('should start game', async () => {
    console.log("run...");
    await expect(page).toClick(".edButton.edGameHeader__button", { text: "Join" });
    await expect(page).toMatchElement(".edLoginDialog", { timeout: 3000 });

    console.log("run...");
    await expect(page).toFill(".edLoginDialog form input", "A");
    await expect(page).toClick(".edLoginDialog__buttons button:nth-child(2)");

    console.log("run...");

    await expect(page).not.toMatchElement(".edLoginDialog");

    console.log("open browser 2...");
    const browser2 = await puppeteer.launch({
      headless: true,
      slowMo: 0,
      args: ['--disable-infobars'],
      timeout: 500,
    })
    const page2 = await browser2.newPage()
    await page2.goto('http://localhost');
    await sleep(100);

    await expect(page2).toClick(".edButton.edGameHeader__button", { text: "Join" });
    await expect(page2).toMatchElement(".edLoginDialog");

    await expect(page2).toFill(".edLoginDialog form input", "B");
    await expect(page2).toClick(".edLoginDialog__buttons button:nth-child(2)");

    await expect(page).toMatch("starting")

    await browser2.close()
  }, 5000);

});

const sleep = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

