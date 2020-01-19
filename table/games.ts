import { CommandResult, Table } from "../types";
import * as db from "../db";

export const addGameEvent = async (table: Table, result: CommandResult) => {
  if (result.type === "TickStart") {
    return db.addGame({ ...table, ...result.table });
  }
};
