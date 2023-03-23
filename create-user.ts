import * as db from "./db";
import { hashPassword } from "./user";

const register = async function(name: string, email: string, password: string) {
  let profile = await db.createUser(
    db.NETWORK_PASSWORD,
    null,
    name,
    null,
    null,
    null
  );
  console.log("created user:", profile);
  password = await hashPassword(password);
  console.log("updating password...");
  profile = await db.updateUser(profile.id, {
    email: email,
    name: null,
    picture: null,
    password: password,
  });
  console.log("done.");
};

const args = process.argv.slice(2);
if (args.length !== 3) {
  console.log("expected name, email, password, but got:", args);
  process.exit(1);
}

(async () => {
  try {
    await db.connect();
    await register(args[0], args[1], args[2]);
    process.exit(0);
  } catch (e) {
    console.error(e);
    process.exit(1);
  }
})();
