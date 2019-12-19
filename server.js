require("ts-node").register({
  cache: process.env.NODE_ENV === "production",
});
if (!require("fs").existsSync("./map-sources.json")) {
  throw new Error("map-sources.json not generated.");
}

require("./main.ts").server();
