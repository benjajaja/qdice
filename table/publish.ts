import {
  Table,
  Player,
  Emoji,
  EliminationReason,
  EliminationSource,
  Command,
  Land,
  CommandResult,
  Color,
  ScoredElimination,
} from "../types";
import {
  serializeTable,
  serializePlayer,
  serializeEliminationReason,
  serializeLand,
} from "./serialize";
import logger from "../logger";
import * as jwt from "jsonwebtoken";
import { MqttClient } from "mqtt";
import { hasChanged } from "../helpers";

let client: MqttClient;
export const setMqtt = (client_: MqttClient) => {
  client = client_;
};

export const tableStatus = (table: Table, clientId?) => {
  client.publish(
    clientId ? `clients/${clientId}` : `tables/${table.tag}/clients`,
    JSON.stringify({
      type: "update",
      payload: serializeTable(table),
      table: clientId ? table.name : undefined,
    }),
    undefined!,
    err => {
      if (err) {
        console.log(err, "tables/" + table.name + "/clients update", table);
      }
    }
  );
};

export const join = (table: Table, player: Player) => {
  client.publish(
    "tables/" + table.name + "/clients",
    JSON.stringify({
      type: "join",
      payload: serializePlayer(table)(player),
    }),
    undefined!,
    err => {
      if (err) {
        console.log(err, "tables/" + table.name + "/clients join", player.name);
      }
    }
  );
};

export const leave = (table: Table, player: Player) => {
  client.publish(
    "tables/" + table.name + "/clients",
    JSON.stringify({
      type: "leave",
      payload: serializePlayer(table)(player),
    }),
    undefined!,
    err => {
      if (err) {
        console.log(
          err,
          "tables/" + table.name + "/clients leave",
          player.name
        );
      }
    }
  );
};

export const enter = (table: Table, name) => {
  client.publish(
    "tables/" + table.name + "/clients",
    JSON.stringify({
      type: "enter",
      payload: name,
    }),
    undefined!,
    err => {
      if (err) {
        console.log(err, "tables/" + table.name + "/clients enter", name);
      }
    }
  );
};

export const exit = (table: Table, name: string | null) => {
  client.publish(
    "tables/" + table.name + "/clients",
    JSON.stringify({
      type: "exit",
      payload: name,
    }),
    undefined!,
    err => {
      if (err) {
        console.log(err, "tables/" + table.name + "/clients exit", name);
      }
    }
  );
};

type Roll = {
  from: { emoji: Emoji; roll: number[] };
  to: { emoji: Emoji; roll: number[] };
  turnStart: number;
  players: readonly Player[];
  capital: Emoji | null;
};
export const roll = (table: Table, roll: Roll) => {
  client.publish(
    "tables/" + table.name + "/clients",
    JSON.stringify({
      type: "roll",
      payload: { ...roll, players: roll.players.map(serializePlayer(table)) },
    }),
    undefined!,
    err => {
      if (err) {
        console.log(err, "tables/" + table.name + "/clients roll", roll);
      }
    }
  );
};

export const move = (table: Table, move: any) => {
  client.publish(
    "tables/" + table.name + "/clients",
    JSON.stringify({
      type: "move",
      payload: move,
    }),
    undefined!,
    err => {
      if (err) {
        console.log(err, "tables/" + table.name + "/clients move", table);
      }
    }
  );
};

export const eliminations = (
  table: Table,
  eliminations: readonly ScoredElimination[],
  players: readonly Player[]
) => {
  const ser = serializePlayer(table);
  client.publish(
    "tables/" + table.name + "/clients",
    JSON.stringify({
      type: "eliminations",
      payload: {
        eliminations: eliminations.map(e => ({
          player: ser(e.player),
          position: e.position,
          score: e.score,
          reason: serializeEliminationReason(table, e.reason, e.source),
        })),
        players: players.map(serializePlayer(table)),
      },
    }),
    undefined!,
    err => {
      if (err) {
        console.log(
          err,
          "tables/" + table.name + "/clients elimination",
          table
        );
      }
    }
  );
};

export const tables = globalTablesUpdate => {
  client.publish(
    "clients",
    JSON.stringify({
      type: "tables",
      payload: globalTablesUpdate,
    }),
    undefined!,
    err => {
      if (err) {
        console.log(err, "clients tables");
      }
    }
  );
};

export const event = event => {
  client.publish("events", JSON.stringify(event), undefined!, err => {
    if (err) {
      console.error("pub telegram error", err);
    }
  });
};

export const eventFromCommand = (
  table: Table,
  command: Command,
  result: CommandResult | null
) => {
  switch (command.type) {
    case "Join":
      event({
        type: "join",
        table: table.name,
        user: command.user,
        bot: !!command.bot,
      });
      return;
    case "Leave":
      event({
        type: "leave",
        table: table.name,
        player: command.player,
      });
      return;
    case "Clear":
      if (result !== null) {
        event({
          type: "clear",
          table: table.name,
        });
      }
      return;
    case "Enter":
    case "Exit":
      event({
        type: "watching",
        table: table.name,
      });
      return;
  }
};

export const clientError = (clientId: string, error: Error) => {
  console.error("client error", clientId, error);
  client.publish(
    `clients/${clientId}`,
    JSON.stringify({
      type: "error",
      payload: error.toString(),
    }),
    undefined!,
    err => {
      if (err) {
        console.error("pub clientError error", err);
      }
    }
  );
  if (!(error instanceof Error)) {
    console.trace("client error must be Error", error);
  }
};

export const chat = (table: Table, user: string | null, message: string) => {
  client.publish(
    "tables/" + table.name + "/clients",
    JSON.stringify({
      type: "chat",
      payload: { user, message },
    }),
    undefined!,
    err => {
      if (err) {
        console.log(err, "tables/" + table.name + "/clients chat", table);
      }
    }
  );
};

export const userUpdate = (clientId: string) => (profile, preferences) => {
  const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET!);
  client.publish(
    `clients/${clientId}`,
    JSON.stringify({
      type: "user",
      payload: [profile, token, preferences],
    }),
    undefined!,
    err => {
      if (err) {
        console.log(err, "tables/?/clients update", clientId);
      }
    }
  );
};

export const turn = (
  table: Table,
  turnIndex: number,
  turnStart: number,
  roundCount: number,
  giveDice: [Player, number] | null,
  players: readonly Player[],
  lands: readonly Land[]
) => {
  client.publish(
    "tables/" + table.name + "/clients",
    JSON.stringify({
      type: "turn",
      payload: {
        turnIndex,
        turnStart: Math.floor(turnStart / 1000),
        roundCount,
        giveDice: giveDice
          ? [serializePlayer(table)(giveDice[0]), giveDice[1]]
          : null,
        players: players.map(serializePlayer(table)),
        lands: lands
          .filter(hasChanged(table.lands))
          .map(serializeLand(players)),
      },
    }),
    undefined!,
    err => {
      if (err) {
        console.log(err, "tables/" + table.name + "/clients turn");
      }
    }
  );
};

export const playerStatus = (table: Table, player: Player) => {
  client.publish(
    "tables/" + table.name + "/clients",
    JSON.stringify({
      type: "player",
      payload: serializePlayer(table)(player),
    }),
    undefined!,
    err => {
      if (err) {
        console.log(err, "tables/" + table.name + "/clients player");
      }
    }
  );
};

export const sigint = async () =>
  new Promise(resolve => {
    client.publish(
      "clients",
      JSON.stringify({
        type: "sigint",
      }),
      undefined!,
      err => {
        if (err) {
          console.log(err, "clients tables");
        }
        resolve();
      }
    );
  });

export const toast = async (message: string) =>
  new Promise(resolve => {
    client.publish(
      "clients",
      JSON.stringify({
        type: "toast",
        payload: message,
      }),
      undefined!,
      err => {
        if (err) {
          console.log(err, "clients");
        }
        resolve();
      }
    );
  });

export const userMessage = async (clientId: string, message: string) =>
  new Promise(resolve => {
    client.publish(
      `clients/${clientId}`,
      JSON.stringify({
        type: "message",
        payload: message,
      }),
      undefined!,
      err => {
        if (err) {
          console.log(err, "clients tables");
        }
        resolve();
      }
    );
  });

export const gameEvent = async (
  tableName: string,
  gameId: number,
  command: Command
) => {
  new Promise(resolve => {
    client.publish(
      "game_events",
      JSON.stringify({
        tableName,
        gameId,
        command,
      }),
      undefined!,
      err => {
        if (err) {
          console.log(err, "clients tables");
        }
        resolve();
      }
    );
  });
};
