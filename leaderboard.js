var R = require('ramda');
const db = require('./db');


module.exports.leaderboard = async function(req, res, next) {
  const top = await db.leaderBoardTop();
  console.log(top);
  res.send(200, {
    month: new Date().toLocaleString('en-us', { month: "long" }),
    top: top,
  });
  next();
};

