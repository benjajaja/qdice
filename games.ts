import * as R from "ramda";
import * as db from "./db";
import logger from "./logger";
import { serializeGame, trimPlayer } from "./table/serialize";
import { Response } from "restify";

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

export const chat = async (req, res: Response, next) => {
  try {
    const chat: any = await db.chat(req.params.table);
    if (req.query.text === "plain") {
      res.sendRaw(
        200,
        chat.map(line => `${line.user?.name}: ${line.message}`).join("\n"),
        { "Content-Type": "text/plain; charset=utf-8" }
      );
    } else {
      res.send(200, chat);
    }
  } catch (e) {
    res.send(500, "Could not get chat");
    logger.error(e);
  } finally {
    next();
  }
};
