import * as R from "ramda";
import * as db from "./db";
import logger from "./logger";

export const profile = async (req, res, next) => {
  logger.debug(req.params);
  const profile = R.omit(
    ["email", "networks", "claimed", "voted"],
    await db.getUser(req.params.id)
  );
  res.send(200, profile);
  next();
};
