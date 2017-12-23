const fs = require('fs');
const R = require('ramda');
const { Grid, HEX_ORIENTATIONS } = require('honeycomb-grid');

const srcDir = process.argv[2];

const grid = Grid({
  size: 100,
  orientation: HEX_ORIENTATIONS.POINTY,
});

const loadMap = rawMap => {
  //const rawMap = fs.readFileSync('./maps/' + tableName + '.emoji')
    //.toString().split('\n').filter(line => line !== '');
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
  process.stdout.write(`caclulating adjacency matrix for ${lands.length} lands...`);
  const result = {
    matrix: lands.map(land => {
      process.stdout.write('.');
      return lands.map(other => isBorder(lands, land.emoji, other.emoji))
    }),
    indexes: lands.reduce((indexes, land, index) => {
      return Object.assign({}, indexes, { [land.emoji]: index });
    }, {}),
  };
  process.stdout.write('\n');
  return result;
};

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

const findLand = lands => emoji => R.find(R.propEq('emoji', emoji))(lands);


const write = fs.createWriteStream('./map-sources.json');
write.write(JSON.stringify({
  maps: fs.readdirSync(srcDir).map(file => {
    const buffer = fs.readFileSync(`${srcDir}/${file}`);
    const lines = buffer.toString().split('\n');
    const name = lines.shift();
    console.log(name);
    const [ lands, adjacency ] = loadMap(lines);
    console.log(`${lands.length} lands`);
    return {
      name,
      lands,
      adjacency,
    };
  }),
}, null, '\t'));

