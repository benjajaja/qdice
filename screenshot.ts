import * as puppeteer from "puppeteer";
import * as config from "./tables.config";

const tableTags = config.tables.map(table => table.tag);

export const screenshot = function(req, res, next) {
  const table = req.params.table;
  if (tableTags.indexOf(table) === -1) {
    res.writeHead(404);
    res.end();
    return;
  }

  (async () => {
    const browser = await puppeteer.launch();
    const page = await browser.newPage();
    await page.setViewport({ width: 800, height: 600 });
    await page.goto(`https://qdice.wtf/${table}?screenshot`, {
      waitUntil: "networkidle2",
    });
    const image = await page.screenshot({});

    browser.close();

    res.writeHead(200);
    res.write(image);
    res.end();
    next();
  })();
};
