import * as R from "ramda";
import * as db from "./db";

export const leaderboard = function(req, res, next) {
  sendLeaderBoard(req, res, next);
};

const sendLeaderBoard = async (req, res, next) => {
  const page = parseInt(req.query.page ?? 1, 10);
  const board = await db.leaderBoardTop(100, page);
  res.send(200, {
    month: new Date().toLocaleString("en-us", { month: "long" }),
    board,
    page,
  });
  next();
};
