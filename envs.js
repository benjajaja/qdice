const fs = require('fs');

const vars = fs.readFileSync('./.env');
vars.toString().split('\n')
  .map(line => line.split('='))
  .forEach(([key, value]) => process.env[key] = value);

