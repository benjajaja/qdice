import {
  Table,
  Player,
  Emoji,
  EliminationReason,
  EliminationSource,
  Command,
} from "../types";
import {
  serializeTable,
  serializePlayer,
  serializeEliminationReason,
} from "./serialize";
import logger from "../logger";
import * as jwt from "jsonwebtoken";
import { MqttClient } from "mqtt";

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

export const elimination = (
  table: Table,
  player: Player,
  position: number,
  score: number,
  reason: EliminationReason,
  source: EliminationSource
) => {
  client.publish(
    "tables/" + table.name + "/clients",
    JSON.stringify({
      type: "elimination",
      payload: {
        player: serializePlayer(table)(player),
        position,
        score,
        reason: serializeEliminationReason(table, reason, source),
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

      event({
        type: "elimination",
        table: table.name,
        player,
        position,
        score,
        reason,
      });
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

export const receivedDice = (table: Table, count: number, player: Player) => {
  client.publish(
    "tables/" + table.name + "/clients",
    JSON.stringify({
      type: "receive",
      payload: { player: serializePlayer(table)(player), count },
    }),
    undefined!,
    err => {
      if (err) {
        console.log(err, "tables/" + table.name + "/clients roll", roll);
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
