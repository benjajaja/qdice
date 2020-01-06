require("ts-node").register({
  cache: process.env.NODE_ENV === "production",
});
require("./hotfix_in_production.ts").fix();
