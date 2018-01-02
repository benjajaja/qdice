const fs = require('fs');
const R = require('ramda');
const { Grid, HEX_ORIENTATIONS } = require('honeycomb-grid');
const { rand } = require('./rand');
const {
  COLOR_NEUTRAL,
} = require('./constants');
const mapJson = require('./map-sources.json');

const grid = Grid({
  size: 100,
  orientation: HEX_ORIENTATIONS.POINTY,
});


module.exports.loadMap = tag => {
  const { lands, adjacency, name } = mapJson.maps
    .filter(R.propEq('tag', tag)).pop();
  return [ lands, adjacency, name ];
};

const isBorder = module.exports.isBorder = ({ indexes, matrix }, from, to) => {
  return matrix[indexes[from]][indexes[to]];
};

module.exports.landMasses = table => color => {
  const colorLands = table.lands.filter(R.propEq('color', color));

  const landMasses = colorLands.reduce((masses, land) => {
    const bordering = masses.filter(mass =>
      mass.some(existing =>
        isBorder(table.adjacency, land.emoji, existing.emoji)));

    if (bordering.length === 0) {
      return R.concat(masses)([ [ land ] ]);
    }
    return masses.map(mass => {
      if (mass === R.head(bordering)) {
        return R.concat(R.concat(mass)([ land ]))(R.unnest(R.tail(bordering)));
      } else if (R.tail(bordering).some(R.equals(mass))) {
        return undefined;
      } else {
        return mass;
      }
    }).filter(R.identity);
  }, []);
  return R.map(R.map(R.prop('emoji')))(landMasses);
};

module.exports.countConnectedLands = table => color => {
  const landMasses = module.exports.landMasses(table)(color);
  const counts = landMasses.map(R.prop('length'));
  return R.reduce(R.max, 0, counts);
};

