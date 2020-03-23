import { CommandResult, Table, Command } from "../types";
import * as db from "../db";

export const addGameEvent = async (
  table: Table,
  command: Command,
  result: CommandResult | null
): Promise<number | null> => {
  if (command.type === "Clear" || command.type === "Heartbeat") {
    return null;
  }
  let gameId =
    command.type === "Start"
      ? (await db.addGame({ ...table, ...(result ?? {}) })).id
      : table.currentGame;

  if (gameId !== null) {
    setImmediate(() => db.addGameEvent(gameId!, command));
  }
  if (command.type === "EndGame") {
    return 0;
  }
  return gameId;
};
