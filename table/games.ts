import { CommandResult, Table } from "../types";
import * as db from "../db";
import logger from "../logger";

export const addGameEvent = async (table: Table, result: CommandResult) => {
  if (result.type === "TickStart") {
    return await db.addGame({ ...table, ...result.table });
  }
  if (table.currentGame === null) {
    logger.warn("addGameEvent but table has no currentGame");
    return;
  }

  setImmediate(() => db.addGameEvent(table.currentGame!, result));
};
