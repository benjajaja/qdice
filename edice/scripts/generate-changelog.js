const fs = require("fs");

const write = fs.createWriteStream("./src/Static/Changelog.elm");
write.write("module Static.Changelog exposing (markdown)\n");
write.write("import Markdown\n");
write.write("\n");
write.write("markdown =\n");
write.write(`    Markdown.toHtml [] """\n`);
write.write("## Changelog\n");
write.write("\n");

const gitlog = require("git-log-reader");

// commits is an array of commit objects
var commits = gitlog.read({
  fields: ["subject", "body", "authorDate"],
});

commits.forEach(commit => {
  write.write(`${commit.authorDate}  \n`);
  write.write(`- ${commit.subject}  \n`);
  if (commit.body) {
    write.write(`  ${commit.body}\n`);
  } else {
    write.write(`  \n`);
  }
});

write.write(`"""\n`);
write.close();
