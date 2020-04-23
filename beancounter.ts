if (process.env.NODE_ENV === "production") {
  const Sentry = require("@sentry/node");
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
  });
}
import * as fs from "fs";
import * as R from "ramda";
import * as mqtt from "mqtt";
import * as Twitter from "twitter";
import { uploadFile } from "s3-bucket";
import * as puppeteer from "puppeteer";

import logger from "./logger";
import * as db from "./db";
import { addGameEvent } from "./table/games";
import { Command } from "./types";
import * as webPush from "web-push";
import { GAME_START_COUNTDOWN } from "./constants";
import { now } from "./timestamp";

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
let browser: puppeteer.Browser;
// (async () =>
// (browser = await puppeteer.launch({
// ignoreHTTPSErrors: true,
// defaultViewport: {
// width: 600,
// height: 400,
// },
// })))();

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
        if (row.subscription && event.user.id !== row.id) {
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
            console.error("push subscription expired, removing", row.id);
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
      case "SitOut":
      case "EndTurn":
        if (browser) {
          try {
            const page = await browser.newPage();
            await page.goto(`${process.env.SCREENSHOT_HOST}/${tableName}`, {
              waitUntil: "networkidle2",
            });
            const filePath = `screenshot_${eventId}.png`;
            await page.screenshot({
              path: `${process.env.SCREENSHOT_PATH}/${filePath}`,
            });
            const url = `${process.env.SCREENSHOT_URL}/${filePath}`;
            await page.close();
            logger.info(url);
          } catch (e) {
            logger.error(e);
          }
        }
        break;

      case "Roll":
        // const success = R.sum(command.fromRoll) > R.sum(command.toRoll);
        // console.log(
        // "attack",
        // command.attacker.name,
        // success ? "SUCCESS" : "FAILED",
        // command.defender?.name ?? "Neutral"
        // );
        break;
    }

    // if (
    // process.env.TWITTER_CONSUMER_KEY &&
    // eventId &&
    // tableName === "Twitter"
    // ) {
    // try {
    // await postTwitterGame(tableName, gameId, command, eventId);
    // } catch (e) {
    // logger.error(e);
    // }
    // }
  }
});

var twitter = new Twitter({
  consumer_key: process.env.TWITTER_CONSUMER_KEY!,
  consumer_secret: process.env.TWITTER_CONSUMER_SECRET!,
  access_token_key: process.env.TWITTER_ACCESS_TOKEN_KEY!,
  access_token_secret: process.env.TWITTER_ACCESS_TOKEN_SECRET!,
});
const twitterGames: { [index: number]: { id: string; table: string } } = {};
const postTwitterGame = async (
  tableName: string,
  gameId: number,
  command: Command,
  eventId: number
) => {
  if (command.type === "Start") {
    const post = await twitter.post("statuses/update", {
      status: `Game #${gameId} with ${command.players
        .map(R.prop("name"))
        .join(", ")} has started https://qdice.wtf/${tableName}!`,
    });
    logger.debug(post);
    twitterGames[gameId] = post.id_str;
  } else {
    const post = twitterGames[gameId];
    if (!post) {
      logger.debug(`no twitter id for game ${gameId}`);
      return;
    }
    let status: string | null = null;
    switch (command.type) {
      case "Roll":
        // status = `${command.attacker.name} attacked ${command.defender?.name ??
        // "Neutral"} from ${command.from} to ${command.to} and ${
        // R.sum(command.fromRoll) > R.sum(command.toRoll)
        // ? "succeeded"
        // : "failed"
        // }`;
        break;
      case "SitOut":
      case "EndTurn":
        const filePath = `screenshot_${eventId}.png`;
        const url = `${process.env.SCREENSHOT_URL}/${filePath}`;
        logger.debug(url);
        status = `${command.player.name}'s turn has finished. ${url}`;
    }
    logger.debug("posting", status);
    if (status !== null) {
      // await twitter.post("statuses/update", {
      // status: `(${eventId}) @qdicewtf ${status}`,
      // in_reply_to_status_id: post,
      // });
    }
  }
};

logger.info("Beancounter is counting beans");
