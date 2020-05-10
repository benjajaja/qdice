if (process.env.NODE_ENV === "production") {
  const Sentry = require("@sentry/node");
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
  });
}
import { promisify } from "util";
import * as R from "ramda";
import * as mqtt from "mqtt";
import * as Twitter from "twitter";
import * as puppeteer from "puppeteer";
import { createHandyClient } from "handy-redis";

import { addRoll, addElimination, addKill } from "./stats";
import logger from "./logger";
import * as db from "./db";
import { addGameEvent } from "./table/games";
import { Command } from "./types";
import * as webPush from "web-push";
import { GAME_START_COUNTDOWN, TURN_SECONDS } from "./constants";
import { now } from "./timestamp";
import { getTable } from "./table/get";

process.on("unhandledRejection", (reason, p) => {
  logger.error("Unhandled Rejection at: Promise", p, "reason:", reason);
  // application specific logging, throwing an error, or other logic here
  throw reason;
});

if (!process.env.VAPID_PUBLIC_KEY || !process.env.VAPID_PRIVATE_KEY) {
  console.log(
    "You must set the VAPID_PUBLIC_KEY and VAPID_PRIVATE_KEY " +
      "environment variables. You can use the following ones:"
  );
  console.log(webPush.generateVAPIDKeys());
} else {
  webPush.setVapidDetails(
    process.env.VAPID_URL!,
    process.env.VAPID_PUBLIC_KEY!,
    process.env.VAPID_PRIVATE_KEY!
  );
}

const redisClient = createHandyClient({
  host: process.env.REDIS_HOST,
});

let browser: puppeteer.Browser;
(async () =>
  (browser = await puppeteer.launch({
    ignoreHTTPSErrors: true,
    defaultViewport: {
      width: 600,
      height: 400,
    },
    args: ["--disable-infobars", "--no-sandbox", "--disable-setuid-sandbox"],
  })))();

var client = mqtt.connect(process.env.MQTT_URL, {
  username: process.env.MQTT_USERNAME,
  password: process.env.MQTT_PASSWORD,
});
client.subscribe("events");
client.subscribe("game_events");
client.on("message", async (topic, message) => {
  if (topic === "events") {
    const event = JSON.parse(message.toString());
    if (event.type === "join") {
      if (!event.user || event.bot) {
        return;
      }
      // push notifications
      if (!process.env.VAPID_PUBLIC_KEY || !process.env.VAPID_PRIVATE_KEY) {
        return;
      }
      const subscriptions = await db.getPushSubscriptions("player-join");
      const text = `${event.user.name} joined table "${event.table}"`;
      subscriptions.forEach(async row => {
        if (
          row.subscription &&
          event.user.id.toString() !== row.id.toString()
        ) {
          console.log("PN", row.id, event.user.id);
          try {
            await webPush.sendNotification(
              row.subscription,
              JSON.stringify({
                type: event.type,
                timestamp: now(),
                table: event.table,
                text,
                link: `https://qdice.wtf/${event.table}`,
              }),
              {
                TTL: GAME_START_COUNTDOWN,
              }
            );
          } catch (e) {
            console.error("push subscription expired, removing", row.id, e);
            try {
              await db.removePushSubscription(row.id, row.subscription);
            } catch (e) {
              console.error(
                "could not remove push subscription",
                JSON.stringify({ id: row.id, subscription: row.subscription }),
                e
              );
            }
          }
        }
      });
    } else if (event.type === "turn") {
      // push notifications
      if (!process.env.VAPID_PUBLIC_KEY || !process.env.VAPID_PRIVATE_KEY) {
        return;
      }
      const subscriptions = await db.getPushSubscription(
        "turn",
        event.player.id
      );
      const text = `It's your turn on "${event.table}!"`;
      if (subscriptions.some(row => row.subscription)) {
        console.log("PN turn", event.player.id, subscriptions);
      }
      subscriptions.forEach(async row => {
        if (!row.subscription) {
          return;
        }
        try {
          await webPush.sendNotification(
            row.subscription,
            JSON.stringify({
              type: event.type,
              timestamp: now(),
              table: event.table,
              text,
              link: `https://qdice.wtf/${event.table}`,
            }),
            {
              TTL: TURN_SECONDS,
            }
          );
        } catch (e) {
          console.error(
            "push subscription expired, removing",
            event.player.id,
            e
          );
          try {
            await db.removePushSubscription(event.player.id, row.subscription);
          } catch (e) {
            console.error(
              "could not remove push subscription",
              JSON.stringify({
                id: event.player.id,
                subscription: row.subscription,
              }),
              e
            );
          }
        }
      });
    } else if (event.type === "countdown") {
      const { table, players } = event;

      // push notifications
      if (!process.env.VAPID_PUBLIC_KEY || !process.env.VAPID_PRIVATE_KEY) {
        return;
      }
      const subscriptions = await db.getPushSubscriptions("game-start");
      const text = `A game countdown has started in "${table}"`;
      subscriptions.forEach(async row => {
        if (
          row.subscription &&
          !players.some((player: any) => player.id === row.id) // don't notify players in game
        ) {
          try {
            const request = await webPush.sendNotification(
              row.subscription,
              JSON.stringify({
                type: event.type,
                timestamp: now(),
                table: event.table,
                text,
                link: `https://qdice.wtf/${event.table}`,
              }),
              {
                TTL: GAME_START_COUNTDOWN,
              }
            );
            console.log("PN", row.name, request);
          } catch (e) {
            // console.error(e);
            // TODO remove subscription if unsubscribed or expired
          }
        }
      });
    } else if (event.type === "elimination") {
      if (!event.player.bot) {
        await addElimination(event.player, event.position);
      }
      if (event.killer && !event.killer.bot) {
        await addKill(event.killer);
      }
    }
  } else if (topic === "game_events") {
    const {
      tableName,
      gameId,
      command,
    }: {
      tableName: string;
      gameId: number;
      command: Command;
    } = JSON.parse(message.toString());

    const eventId = await addGameEvent(tableName, gameId, command);

    switch (command.type) {
      case "Roll":
        if (command.round > 1) {
          await addRoll(
            command.attacker,
            command.fromRoll,
            command.defender,
            command.toRoll
          );
        }
        break;
    }

    if (
      !process.env.E2E &&
      process.env.TWITTER_CONSUMER_KEY &&
      eventId &&
      tableName === "Twitter"
    ) {
      try {
        await postTwitterGame(tableName, gameId, command, eventId);
      } catch (e) {
        logger.error(e);
      }
    }
  }
});

var twitter = process.env.TWITTER_ENABLED
  ? new Twitter({
      consumer_key: process.env.TWITTER_CONSUMER_KEY!,
      consumer_secret: process.env.TWITTER_CONSUMER_SECRET!,
      access_token_key: process.env.TWITTER_ACCESS_TOKEN_KEY!,
      access_token_secret: process.env.TWITTER_ACCESS_TOKEN_SECRET!,
    })
  : null;

const postTwitterGame = async (
  tableName: string,
  gameId: number,
  command: Command,
  eventId: number
) => {
  if (!twitter) {
    return;
  }
  if (command.type === "Start") {
    const data = await screenshot(tableName, eventId);
    const media = await twitter.post("media/upload", { media: data });
    const params = {
      status: `Game #${gameId} with ${command.players
        .map(R.prop("name"))
        .join(", ")} has started! https://qdice.wtf/${tableName}!`,
      media_ids: media.media_id_string,
    };
    const post = await twitter.post("statuses/update", params);
    logger.debug(post);
    await redisClient.set("twitter_game", post.id_str);
  } else if (command.type === "EndGame") {
    const post = await redisClient.get("twitter_game");
    if (!post) {
      logger.debug(`no twitter id for game ${gameId}`);
      return;
    }
  } else {
    const post = await redisClient.get("twitter_game");
    if (!post) {
      logger.debug(`no twitter id for game ${gameId}`);
      return;
    }
    let params: any;
    switch (command.type) {
      case "Roll":
        params = {
          status: `(${eventId}) @qdicewtf ${
            command.attacker.name
          } attacked ${command.defender?.name ?? "Neutral"} from ${
            command.from
          } to ${command.to} and ${
            R.sum(command.fromRoll) > R.sum(command.toRoll)
              ? "succeeded"
              : "failed"
          }`,
          in_reply_to_status_id: post,
        };
        break;
      case "SitOut":
      case "EndTurn":
        const data = await screenshot(tableName, eventId);
        const media = await twitter.post("media/upload", { media: data });
        params = {
          status: `(${eventId}) @qdicewtf ${command.player?.name ??
            "Unknown"}'s turn has finished.`,
          in_reply_to_status_id: post,
          media_ids: media.media_id_string,
        };
    }
    logger.debug("posting", params);
    if (params !== null) {
      await twitter.post("statuses/update", params);
    }
  }
};

const screenshot = async (tableName: string, id: number) => {
  const page = await browser.newPage();
  await page.goto(`${process.env.SCREENSHOT_HOST}/${tableName}`, {
    waitUntil: "networkidle2",
  });
  await page.waitFor(5000);

  // const filePath = `screenshot_${id}.png`;
  const data = await page.screenshot({
    encoding: "binary",
    // path: `/screenshots/${filePath}`,
  });
  await page.close();
  // return `${process.env.SCREENSHOT_URL}/${filePath}`;
  return data;
};

const listen = async () => {
  if (!twitter) {
    return;
  }
  const post = await redisClient.get("twitter_game");
  if (!post) {
    return logger.info("no ongoing twitter game");
  }
  const stream = twitter.stream("statuses/filter", {
    track: "qdicewtf",
  });
  stream.on("data", async event => {
    const text: string = event.text;
    if (/end turn/.test(text)) {
      const table = await getTable("Twitter");
      const player = table.players[table.turnIndex];
      const command = { type: "EndTurn", user: player };
      client.publish("tables/Twitter/server", JSON.stringify(command));
    } else {
      const matches = text.match(/\u3000|[\uD800-\uDBFF][\uDC00-\uDFFF]/g);
      if (!matches || matches.length !== 2) {
        logger.debug("no emojis", text);
        return;
      }
      const [from, to] = matches.slice();
      logger.debug("attack", from, to);

      const table = await getTable("Twitter");
      const player = table.players[table.turnIndex];
      const command = { type: "Attack", payload: [from, to], user: player };
      client.publish("tables/Twitter/server", JSON.stringify(command));
    }
  });
  stream.on("error", error => {
    logger.error("event", error);
    (stream as any).destroy();
    setTimeout(listen, 1000);
  });
};
listen();

logger.info("Beancounter is connecting to postgres...");
(async () => {
  await db.retry();
  logger.info("Beancounter is counting beans.");
})();
