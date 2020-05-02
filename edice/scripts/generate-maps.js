const fs = require("fs");
const R = require("ramda");

const srcDir = process.argv[2];
const writeMaps = process.argv[3];

const cubeFromAxial = (col, row) => {
  const cubeX = col - ((row - (row & 1)) >> 1);
  return { x: cubeX, z: row, y: -cubeX - row };
};

const loadMap = rawLines => {
  const regex = new RegExp(
    "\\u30C3|\\u3000|[\\uD800-\\uDBFF][\\uDC00-\\uDFFF]",
    "gi"
  );

  const [rawMap, extraConnections] =
    rawLines[rawLines.length - 2].indexOf("water:") === 0
      ? [
          rawLines.slice(0, rawLines.length - 2),
          rawLines[rawLines.length - 2]
            .split(":")[1]
            .split(",")
            .map(pair => {
              const results = [];
              let result;
              while ((result = regex.exec(pair))) {
                results.push(result[0]);
              }
              return results;
            }),
        ]
      : [rawLines, []];

  const lines = rawMap.map(line => {
    const results = [];
    let result;
    while ((result = regex.exec(line))) {
      results.push(result[0]);
    }
    return results;
  });
  // const width = lines
  // .map(row => row.length)
  // .reduce((max, width) => Math.max(max, width));
  // const height = lines.length;

  const emptyLands = R.uniq(lines.reduce(R.concat, []))
    .filter(R.complement(R.equals("〿")))
    .filter(R.complement(R.equals("ｯ")))
    .filter(R.complement(R.equals("\u3000")))
    .map(emoji => ({
      emoji: emoji,
      cells: [],
    }));

  const lands = lines.reduce((lands, line, row) => {
    return line.reduce((lands, char, col) => {
      const cell = { row, col };
      return lands.map(land => {
        if (land.emoji === char) {
          return { ...land, cells: land.cells.concat([cell]) };
        }
        return land;
      });
    }, lands);
  }, emptyLands);

  const adjacency = createAdjacencyMatrix(lands, extraConnections);
  return [lands, adjacency];
};

const createAdjacencyMatrix = (lands, extra) => {
  process.stdout.write(
    `calculating adjacency matrix for ${lands.length} lands...`
  );
  const result = {
    matrix: lands.map(land => {
      process.stdout.write(".");
      return lands.map(other =>
        isBorder(lands, extra, land.emoji, other.emoji)
      );
    }),
    indexes: lands.reduce((indexes, land, index) => {
      return Object.assign({}, indexes, { [land.emoji]: index });
    }, {}),
  };
  process.stdout.write("\n");
  return result;
};

const isBorder = (lands, extra, fromEmoji, toEmoji) => {
  if (fromEmoji === toEmoji) {
    return false;
  }
  if (
    extra.some(
      pair => pair.indexOf(fromEmoji) !== -1 && pair.indexOf(toEmoji) !== -1
    )
  ) {
    return true;
  }
  const find = findLand(lands);
  const from = find(fromEmoji);
  const to = find(toEmoji);
  return from.cells.some(fromCell =>
    to.cells.some(toCell => {
      return neighbors(fromCell).some(
        neighbor => neighbor.row === toCell.row && neighbor.col === toCell.col
      );
    })
  );
};

const cube = (x, y, z) => ({ x, y, z });
const cubeDirections = [
  cube(+1, -1, 0),
  cube(+1, 0, -1),
  cube(0, +1, -1),
  cube(-1, +1, 0),
  cube(-1, 0, +1),
  cube(0, -1, +1),
];
const oddrDirections = [
  [
    [+1, 0],
    [0, -1],
    [-1, -1],
    [-1, 0],
    [-1, +1],
    [0, +1],
  ],
  [
    [+1, 0],
    [+1, -1],
    [0, -1],
    [-1, 0],
    [0, +1],
    [+1, +1],
  ],
];

const neighborAt = (hex, direction) => {
  const parity = hex.row & 1;
  const dir = oddrDirections[parity][direction];
  return { col: hex.col + dir[0], row: hex.row + dir[1] };
};
const neighbors = hex => [0, 1, 2, 3, 4, 5].map(i => neighborAt(hex, i));

const findLand = lands => emoji => R.find(R.propEq("emoji", emoji))(lands);

const [maps, clientMaps] = fs.readdirSync(srcDir).reduce(
  ([dict, clientMaps], file) => {
    const buffer = fs.readFileSync(`${srcDir}/${file}`);
    const lines = buffer.toString().split("\n");
    const name = lines.shift();
    console.log(name);
    const [lands, adjacency] = loadMap(lines);
    console.log(`${lands.length} lands`);
    dict[name] = {
      name,
      tag: name,
      lands,
      adjacency,
      source: buffer.toString(),
    };

    clientMaps.push([buffer.toString(), adjacency]);
    return [dict, clientMaps];
  },
  [{}, []]
);

const mapSources = fs.writeFileSync(
  "./map-sources.json",
  JSON.stringify(
    {
      maps: maps,
    },
    null,
    "\t"
  )
);

// client maps (elm file)
if (!writeMaps) {
  process.exit(0);
}
console.log("Generating Elm map sources");

if (!fs.existsSync(`${writeMaps}/src/Maps`)) {
  fs.mkdirSync(`${writeMaps}/src/Maps`);
}
const write = fs.createWriteStream(`${writeMaps}/src/Maps/Sources.elm`);
write.write("module Maps.Sources exposing (mapSourceString, mapAdjacency)\n");
write.write("import Tables exposing (MapName(..))\n");
write.write("\n");
write.write("mapSourceString : MapName -> String\n");
write.write("mapSourceString table =\n");
write.write("    case table of\n");

const mapNames = [];
clientMaps.forEach(([str, adjacency]) => {
  const lines = str.split("\n");
  const name = lines.shift();
  const matrixString = adjacency.matrix
    .map(row =>
      row.reduce((array, bit, i) => [...array, bit ? 1 : 0], []).join("")
    )
    .join(",");
  write.write("        " + name + " ->\n");
  write.write('            """\n');
  write.write(lines.join("\n"));
  write.write('"""\n');
  write.write("\n");

  mapNames.push(name);

  console.log(`Generated emoji map: "${name}"`);
});

write.write("\n");
write.write("mapAdjacency : MapName -> (List (String, Int), List (List Int))\n");
write.write("mapAdjacency table =\n");
write.write("    case table of\n");
clientMaps.forEach(([str, adjacency]) => {
  const lines = str.split("\n");
  const name = lines.shift();
  const matrixString = adjacency.matrix
    .map(row =>
      row.reduce((array, bit, i) => [...array, bit ? 1 : 0], []).join("")
    )
    .join(",");

  write.write("        " + name + " ->\n");
  write.write("            ([\n");
  write.write(
    "                " +
      Object.keys(adjacency.indexes)
        .map((e, i) => `("${e}",${i})`)
        .join(",") +
      "\n"
  );
  write.write("                ]\n");
  write.write(
    "            ,[[" +
      adjacency.matrix
        .map(row => row.map(b => (b ? 1 : 0)).join(","))
        .join("]\n                ,[") +
      "\n"
  );
  write.write("            ]])");
  write.write("\n");

  console.log(`Generated adjacency: "${name}"`);
});

const mapNamesJson = fs.createWriteStream(`${writeMaps}/html/mapnames.json`);
mapNamesJson.write(JSON.stringify(mapNames));
mapNamesJson.close();
