import { CommandResult, Table, Command } from "../types";
import * as db from "../db";

export const startGameEvent = async (
  table: Table,
  result: CommandResult | null
): Promise<number | null> => {
  return (await db.addGame({ ...table, ...(result ?? {}) })).id;
};

export const addGameEvent = async (
  tableName: string,
  gameId: number,
  command: Command
): Promise<number | null> => {
  if (command.type === "Clear" || command.type === "Heartbeat") {
    return null;
  }

  if (
    command.type === "Chat" &&
    command.user &&
    ((command.user as any).id ?? "").indexOf("bot_") === 0
  ) {
    return null;
  }

  const event = await db.addGameEvent(gameId!, command);

  if (command.type === "EndGame") {
    return 0;
  }
  return event.id;
};
