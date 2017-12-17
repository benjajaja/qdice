const fs = require('fs');
const R = require('ramda');
const { Grid, HEX_ORIENTATIONS } = require('honeycomb-grid');
const { rand } = require('./rand');

const grid = Grid({
  size: 100,
  orientation: HEX_ORIENTATIONS.POINTY,
});

module.exports.loadMap = tableName => {
  const rawMap = fs.readFileSync('./maps/' + tableName + '.emoji')
    .toString().split('\n').filter(line => line !== '');
  const regex = new RegExp('〿|\\u3000|[\\uD800-\\uDBFF][\\uDC00-\\uDFFF]', 'gi');

  const rows = rawMap.map(line => {
    const results = [];
    let result;
    let index = 0;
    while (result = regex.exec(line)){
      results.push(result[0]);
      index++;
    }
    return results;
  });
  //const maxWidth = rows.map(row => row.length).reduce((max, width) => Math.max(max, width));
  const lands = R.uniq(rows.reduce(R.concat, []))
    .filter(R.complement(R.equals('〿')))
    .filter(R.complement(R.equals('\u3000')))
    .map(emoji => ({
      emoji: emoji,
      color: -1,
      points: rand(1, 5),
    }));

  const fullLands = lands.map(land => {
    const cells = rows.reduce((cells, row, y) => {
      return row.reduce((rowCells, char, x) => {
        if (char !== land.emoji) {
          return rowCells;
        } else {
          //const x_ = rowCells[0] === '〿' ? x - 1 : x;
          return rowCells.concat([
            grid.Hex(x, y + 1)
          ]);
        }
      }, cells);
    }, []);
    return Object.assign(land, { cells });
  });
  return [ fullLands, createAdjacencyMatrix(fullLands) ];
};

const createAdjacencyMatrix = lands => {
  return {
    matrix: lands.map(land => {
      return lands.map(other => isBorder(lands, land.emoji, other.emoji))
    }),
    indexes: lands.reduce((indexes, land, index) => {
      return Object.assign({}, indexes, { [land.emoji]: index });
    }, {}),
  };
};
const findLand = lands => emoji => R.find(R.propEq('emoji', emoji))(lands);

const isBorder = module.exports.isBorder = R.curry((lands, fromEmoji, toEmoji) => {
  if (fromEmoji === toEmoji) {
    return false;
  }
  const find = findLand(lands);
  const from = find(fromEmoji);
  const to = find(toEmoji);
  return from.cells.some(fromCell => to.cells.some(toCell => {
    return grid.Hex.neighbors(fromCell).some(neighbor => {
      return R.equals(neighbor, toCell);
    });
  }));
});

module.exports.landMasses = table => color => {
  const colorLands = table.lands.filter(R.propEq('color', color));

  //const isBorder_ = isBorder(colorLands);
  const { indexes, matrix } = table.adjacency;
  const isBorder_ = (from, to) => {
    return matrix[indexes[from]][indexes[to]];
  };
  const landMasses = colorLands.reduce((masses, land) => {
    const bordering = masses.filter(mass =>
      mass.some(existing =>
        isBorder_(land.emoji, existing.emoji)));

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

