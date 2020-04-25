import * as R from "ramda";
import * as db from "./db";
import logger from "./logger";
import * as errs from "restify-errors";

export const profile = async (req, res, next) => {
  try {
    if (req.params.id.indexOf("bot_") === 0) {
      return next(
        new errs.InvalidArgumentError("This is a bot, it has no profile")
      );
    }
    const user = await db.getUser(req.params.id);
    const profile = {
      ...R.omit(["email", "networks", "claimed", "voted"], user),
      registered: user.networks.length > 0,
    };
    const stats = await db.getUserStats(req.params.id);
    res.send(200, { profile, stats });
    next();
  } catch (e) {
    next(e);
  }
};
