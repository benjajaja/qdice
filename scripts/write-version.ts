import { createWriteStream, readFileSync } from "fs";

if (!process.argv[2]) {
  throw new Error("No version provided");
}
const write = createWriteStream("./version");
write.write(process.argv[2].toString());
write.close();
console.log(`version file written: ${process.argv[2].toString()}`);
