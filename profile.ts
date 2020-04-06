import * as R from "ramda";
import * as db from "./db";
import logger from "./logger";
import * as errs from "restify-errors";
import { serializeGame } from "./table/serialize";

export const profile = async (req, res, next) => {
  try {
    if (req.params.id.indexOf("bot_") === 0) {
      return next(
        new errs.InvalidArgumentError("This is a bot, it has no profile")
      );
    }
    const profile = R.omit(
      ["email", "networks", "claimed", "voted"],
      await db.getUser(req.params.id)
    );
    const rawStats = await db.getUserStats(req.params.id);
    const stats = { games: rawStats.games.map(serializeGame) };
    res.send(200, { profile, stats });
    next();
  } catch (e) {
    next(e);
  }
};
