import * as R from "ramda";
import * as db from "./db";

export const leaderboard = function(req, res, next) {
  sendLeaderBoard(req, res, next);
};

const sendLeaderBoard = async (req, res, next) => {
  const top = await db.leaderBoardTop();
  console.log(top);
  res.send(200, {
    month: new Date().toLocaleString("en-us", { month: "long" }),
    top: top,
  });
  next();
};
