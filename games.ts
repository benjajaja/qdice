import * as R from "ramda";
import * as db from "./db";

export const games = async (req, res, next) => {
  const games: any = await db.games(req.query?.table);
  res.send(200, games.map(serializeGame));
  next();
};

export const game = async (req, res, next) => {
  const game = await db.game(req.params.id);
  res.send(200, serializeGame(game));
  next();
};

const serializeGame = game => ({
  ...game,
  players: game.players.map(R.pick(["id", "name", "picture", "color"])),
});
