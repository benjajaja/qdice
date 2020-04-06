import * as R from "ramda";
import * as db from "./db";
import logger from "./logger";
import { serializeGame } from "./table/serialize";

export const games = async (req, res, next) => {
  try {
    const games: any = await db.games(req.params.table);
    res.send(200, games.map(serializeGame));
  } catch (e) {
    res.send(500, "Could not get games");
    logger.error(e);
  } finally {
    next();
  }
};

export const game = async (req, res, next) => {
  try {
    const game = await db.game(req.params.id);
    res.send(200, [serializeGame(game)]);
  } catch (e) {
    res.send(500, "Could not get games");
    logger.error(e);
  } finally {
    next();
  }
};
