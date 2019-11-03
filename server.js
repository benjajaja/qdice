require('ts-node').register({
});
if (!require('fs').existsSync('./map-sources.json')) {
  throw new Error("map-sources.json not generated.");
}

require('./main.ts')
