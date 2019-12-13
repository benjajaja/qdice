const fs = require("fs");

const write = fs.createWriteStream("./src/Static/Changelog.elm");
write.write("module Static.Changelog exposing (markdown)\n");
write.write("import Markdown\n");
write.write("\n");
write.write("markdown =\n");
write.write(`    Markdown.toHtml [] """\n`);
write.write("## Changelog\n");
write.write("\n");

const commits = process.env.git_log.split("---\n");

if (commits.length === 0) {
  throw new Error("empty git_log env variable");
}
commits.forEach(commit => {
  const [hash, date, ...rest] = commit.split("\n");
  write.write(`${hash} - ${date}\n\n`);
  rest.forEach((line, i) => {
    if (i === 0) {
      write.write(`> **${line}**\n\n`);
    } else {
      write.write(`> ${line}\n\n`);
    }
  });
  write.write(`\n`);
});

write.write(`"""\n`);
write.close();

console.log("Changelog entries: " + commits.length);
