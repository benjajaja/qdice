const fs = require("fs");

const write = fs.createWriteStream("./src/Static/Changelog.elm");
write.write("module Static.Changelog exposing (markdown)\n");
write.write("import Markdown\n");
write.write("\n");
write.write("markdown =\n");
write.write(`    Markdown.toHtml [] """\n`);
write.write("## Changelog\n");
write.write("\n");

const lines = process.env.git_log.split("\n");

if (lines.length === 0) {
  throw new Error("empty git_log env variable");
}
lines.forEach(line => {
  write.write(`- ${line}  \n`);
});

write.write(`"""\n`);
write.close();

console.log("Changelog entries: " + lines.length);
