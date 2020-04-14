import { createWriteStream, readFileSync } from "fs";

const write = createWriteStream("./changelog.md");

const commits = (process.env.git_log
  ? process.env.git_log
  : readFileSync("/dev/stdin").toString()
).split("---\n");

if (commits.length === 0) {
  throw new Error("git log is empty");
}

const header = `## Changelog

Generated from git changelog.  See repo here: [github.com/gipsy-king/qdice](https://github.com/gipsy-king/qdice)

`;

const entries = commits.reduce((md, commit) => {
  const [date, hash, ...rest] = commit.split("\n");
  const link = `[${hash}](https://github.com/gipsy-king/qdice/commit/${hash})`;
  return (
    md +
    `${link} - ${date}\n\n` +
    rest.reduce((str, line, i) => {
      if (i === 0) {
        return str + `> **${line}**\n\n`;
      } else {
        return str + `> ${line}\n\n`;
      }
    }, "") +
    "\n"
  );
}, header);

write.write(entries);
write.close();

console.log("Changelog entries: " + commits.length);
