require("ts-node").register({
  cache: process.env.NODE_ENV === "production",
});
require("./toast.ts").toast(process.argv);
