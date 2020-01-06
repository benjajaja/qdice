import logger from "./logger";
logger.info("Awards script started");

import * as db from "./db";
import { date, now } from "./timestamp";
import { Award } from "./types";

export const awards = async () => {
  switch (process.argv[2]) {
    case "monthly":
      await monthly();
      break;
    case "early_adopters":
      await earlyAdopters();
      break;
    default:
      throw new Error("unknown award type");
  }
  process.exit(0);
};

const monthly = async () => {
  const client = await db.retry();
  logger.info("connected to postgres.");

  const leaderboard = await db.leaderBoardTop(30);

  const timestamp = date(now());
  try {
    await client.query("BEGIN");
    await Promise.all(
      leaderboard.map(async entry => {
        const user = await db.getUser(entry.id);
        const text = `UPDATE users SET awards = $1 WHERE id = $2`;
        const award: Award = {
          type: "monthly_rank",
          position: entry.rank,
          timestamp,
        };
        logger.info(`User ${user.id} got award ${JSON.stringify(award)}`);
        return await client.query(text, [
          JSON.stringify(user.awards.concat([award])),
          entry.id,
        ]);
      })
    );
    await client.query("UPDATE users SET points = 0");
    await client.query("COMMIT");
  } catch (e) {
    logger.error(e);
    await client.query("ROLLBACK");
    throw e;
  }
};

const earlyAdopters = async () => {
  const client = await db.retry();
  logger.info("connected to postgres.");

  const users = await client.query("SELECT id, name FROM users");

  const timestamp = date(now());
  logger.info(`adding early_adopter award to ${users.rows.length} users`);
  try {
    client.query("BEGIN");
    await Promise.all(
      users.rows.map(async entry => {
        const user = await db.getUser(entry.id);
        const text = `UPDATE users SET awards = $1 WHERE id = $2 RETURNING id,name,awards`;
        const award: Award = {
          type: "early_adopter",
          position: 0,
          timestamp,
        };
        if (entry.id == "404") {
          logger.debug(text);
          logger.debug([user.awards.concat([award]), entry.id]);
        }
        const result = await client.query(text, [
          JSON.stringify(user.awards.concat([award])),
          user.id,
        ]);
        logger.debug("result", result.rows);
      })
    );
    await client.query("COMMIT");
    logger.info("COMMITted");
  } catch (e) {
    logger.error(e);
    await client.query("ROLLBACK");
    throw e;
  }
};
