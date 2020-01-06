import logger from "./logger";
logger.info("HOTFIX script started");

import * as db from "./db";
import { downloadPicture } from "./helpers";

export const fix = async () => {
  const client = await db.retry();
  logger.info("connected to postgres.");

  try {
    // await client.query("BEGIN");
    const result = await client.query(
      `SELECT id, name, picture FROM users WHERE picture != ''`
    );
    await Promise.all(
      result.rows.map(async row => {
        if (row.picture.indexOf("http") !== 0) {
          return;
        }

        try {
          const picture = await downloadPicture(row.id, row.picture);
          logger.debug(`would update ${row.id} ${row.picture} -> ${picture}`);
          await db.updateUser(row.id, {
            name: null,
            email: null,
            picture,
          });
        } catch (e) {
          logger.error(`can't download ${row.picture}`, e);
          await db.updateUser(row.id, {
            name: row.name,
            email: null,
            picture: "",
          });
        }
      })
    );
  } catch (err) {
    logger.error("fix", err);
  }
  process.exit(0);
};
