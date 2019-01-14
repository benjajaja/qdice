const fs = require('fs');

const write = fs.createWriteStream('./src/Maps/Sources.elm');
write.write('module Maps.Sources exposing (mapSourceString)\n');
write.write('import Tables exposing (Map(..))\n');
write.write('\n');
write.write('mapSourceString : Map -> String\n');
write.write('mapSourceString table =\n');
write.write('    case table of\n');

fs.readdirSync('./maps').sort().forEach(file => {
  const buffer = fs.readFileSync(`./maps/${file}`);
  const lines = buffer.toString().split('\n');
  const name = lines.shift();
  //const tag = lines.shift();
  write.write('        ' + name + ' ->\n');
  write.write('            """\n');
  write.write(lines.join('\n'));
  write.write('"""\n');
  write.write('\n');
  console.log(name);
});

