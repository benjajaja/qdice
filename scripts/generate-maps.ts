import * as fs from "fs";
import * as R from "ramda";

// type Hex = {x: number; y: number; z: number};
type Hex = { row: number; col: number };
type Land = { emoji: string; cells: Hex[] };

const srcDir = process.argv[2];
const writeMaps = process.argv[3];

const cubeFromAxial = (col: number, row: number) => {
  const cubeX = col - ((row - (row & 1)) >> 1);
  return { x: cubeX, z: row, y: -cubeX - row };
};

const loadMap = (
  rawLines: string[]
): [{ emoji: string; cells: any[] }[], { matrix: any; indexes: any }] => {
  const regex = new RegExp(
    "\\u30C3|\\u3000|[\\uD800-\\uDBFF][\\uDC00-\\uDFFF]",
    "gi"
  );

  const [rawMap, extraConnections]: [string[], [string, string][]] =
    rawLines[rawLines.length - 2].indexOf("water:") === 0
      ? [
          rawLines.slice(0, rawLines.length - 2),
          rawLines[rawLines.length - 2]
            .split(":")[1]
            .split(",")
            .map(pair => {
              const results: string[] = [];
              let result: any;
              while ((result = regex.exec(pair))) {
                results.push(result[0]);
              }
              return results as any;
            }),
        ]
      : [rawLines, []];

  const lines = rawMap.map(line => {
    const results: string[] = [];
    let result: any;
    while ((result = regex.exec(line))) {
      results.push(result[0]);
    }
    return results;
  });
  // const width = lines
  // .map(row => row.length)
  // .reduce((max, width) => Math.max(max, width));
  // const height = lines.length;

  const emptyLands: Land[] = R.uniq(lines.reduce(R.concat, []))
    .filter(R.complement(R.equals("〿")))
    .filter(R.complement(R.equals("ｯ")))
    .filter(R.complement(R.equals("\u3000")))
    .map((emoji: string) => ({
      emoji: emoji,
      cells: [],
    }));

  const lands = lines.reduce<Land[]>((lands, line, row) => {
    return line.reduce<Land[]>((lands, char, col) => {
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

const createAdjacencyMatrix = (lands: Land[], extra: [string, string][]) => {
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

const isBorder = (
  lands: Land[],
  extra: [string, string][],
  fromEmoji: string,
  toEmoji: string
) => {
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

const cube = (x: number, y: number, z: number) => ({ x, y, z });
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

const neighborAt = (hex: Hex, direction: number): Hex => {
  const parity = hex.row & 1;
  const dir = oddrDirections[parity][direction];
  return { col: hex.col + dir[0], row: hex.row + dir[1] };
};
const neighbors = (hex: Hex): Hex[] =>
  [0, 1, 2, 3, 4, 5].map(i => neighborAt(hex, i));

const findLand = (lands: Land[]) => (emoji: string) =>
  R.find<Land>(R.propEq("emoji", emoji))(lands)!;

const [maps, clientMaps] = fs.readdirSync(srcDir).reduce(
  ([dict, clientMaps], file) => {
    const buffer = fs.readFileSync(`${srcDir}/${file}`);
    const lines = buffer.toString().split("\n");
    const name = lines.shift()!;
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
  [{}, [] as [string, { indexes: any[]; matrix: any[] }][]]
);

const mapSources = fs.createWriteStream("./map-sources.json");
mapSources.write(
  JSON.stringify(
    {
      maps: maps,
    },
    null,
    "\t"
  )
);
mapSources.close();

// client maps (elm file)

if (!fs.existsSync("./edice/src/Maps")) {
  fs.mkdirSync("./edice/src/Maps");
}
const write = fs.createWriteStream("./edice/src/Maps/Sources.elm");
write.write("module Maps.Sources exposing (mapSourceString)\n");
write.write("import Tables exposing (Map(..))\n");
write.write("\n");
write.write("mapSourceString : Map -> String\n");
write.write("mapSourceString table =\n");
write.write("    case table of\n");

const mapNames: string[] = [];
clientMaps.forEach(([str, adjacency]) => {
  const lines = str.split("\n");
  const name = lines.shift()!;
  const matrixString = adjacency.matrix
    .map(row =>
      row.reduce((array, bit, i) => [...array, bit ? 1 : 0], []).join("")
    )
    .join(",");
  write.write("        " + name + " ->\n");
  write.write('            """\n');
  write.write(lines.join("\n"));
  write.write("indices:" + Object.keys(adjacency.indexes).join("") + "\n");
  write.write("matrix:" + matrixString + "\n");
  write.write('"""\n');
  write.write("\n");

  mapNames.push(name);

  console.log(`Generated map: "${name}"`);
});
write.close();

const mapNamesJson = fs.createWriteStream("./edice/html/mapnames.json");
mapNamesJson.write(JSON.stringify(mapNames));
mapNamesJson.close();
