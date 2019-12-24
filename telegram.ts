import * as https from "https";
import * as fs from "fs";
import * as path from "path";
import * as Telegram from "telegraf/telegram";
import * as Telegraf from "telegraf";
import * as Extra from "telegraf/extra";
import * as Markup from "telegraf/markup";
import * as jwt from "jsonwebtoken";
import * as ShortUniqueId from "short-unique-id";
import * as R from "ramda";
import * as puppeteer from "puppeteer";
import * as mqtt from "mqtt";
import * as webPush from "web-push";
import * as Twitter from "twitter";
import { rand } from "./rand";
import * as db from "./db";
import logger from "./logger";

webPush.setVapidDetails(
  process.env.VAPID_URL!,
  process.env.VAPID_PUBLIC_KEY!,
  process.env.VAPID_PRIVATE_KEY!
);

const telegram = new Telegram(process.env.BOT_TOKEN);
var twitter = new Twitter({
  consumer_key: process.env.TWITTER_CONSUMER_KEY,
  consumer_secret: process.env.TWITTER_CONSUMER_SECRET,
  access_token_key: process.env.TWITTER_ACCESS_TOKEN_KEY,
  access_token_secret: process.env.TWITTER_ACCESS_TOKEN_SECRET,
});
const uid = new ShortUniqueId();

const officialGroups = process.env.BOT_OFFICIAL_GROUPS
  ? process.env.BOT_OFFICIAL_GROUPS.split(",")
  : [];

console.log("connecting to mqtt: " + process.env.MQTT_URL);
var client = mqtt.connect(process.env.MQTT_URL, {
  username: process.env.MQTT_USERNAME,
  password: process.env.MQTT_PASSWORD,
});
client.subscribe("events");

var lastJoinPlayer: string | null = null;
client.on("message", async (topic, message) => {
  if (topic === "events") {
    const event = JSON.parse(message.toString());
    if (event.type === "join") {
      if (!event.player) {
        return;
      }
      subscribed.forEach(id =>
        telegram
          .sendMessage(
            id,
            `${event.player.name} joined https://qdice.wtf/${event.table}`
          )
          .catch(e => console.error(e))
      );
      if (lastJoinPlayer === event.player.id) {
        return;
      }
      lastJoinPlayer = event.player.id;
      // push notifications
      const subscriptions = await db.getPushSubscriptions("player-join");
      const text = `${event.player.name} joined table "${event.table}"`;
      subscriptions.forEach(async row => {
        if (row.subscription && event.player.id !== row.id) {
          console.log("PN", row.id, event.player.id);
          try {
            const request = await webPush.sendNotification(
              row.subscription,
              JSON.stringify({ text, link: `https://qdice.wtf/${event.table}` })
            );
          } catch (e) {
            console.error(e);
            // TODO remove subscription if unsubscribed or expired
          }
        }
      });

      if (process.env.TWITTER_CONSUMER_KEY) {
        try {
          await twitter.post("statuses/update", {
            status: `A game with "${event.player.name}" is about to start at https://qdice.wtf/${event.table}. Play now!`,
          });
        } catch (e) {
          logger.error(e);
        }
      }

      //if (officialGroups.length) {
      //const { table, players } = event;
      //officialGroups.forEach(id => {
      //sendScreenshot(id, table);
      //});
      //}

      // case "elimination":
      // if (event.player.telegram) {
      // setScore(event.player.telegram, event.player.points);
      // }
      // break;
    } else if (event.type === "countdown") {
      console.log("offical", officialGroups);
      const { table, players } = event;

      // push notifications
      const subscriptions = await db.getPushSubscriptions("game-start");
      const text = `A game countdown has started in "${table}"`;
      subscriptions.forEach(async row => {
        if (
          row.subscription &&
          !players.some(player => player.id === row.id) // don't notify players in game
        ) {
          try {
            const request = await webPush.sendNotification(
              row.subscription,
              JSON.stringify({ text, link: `https://qdice.wtf/${table}` })
            );
            console.log("PN", row.name, request);
          } catch (e) {
            // console.error(e);
            // TODO remove subscription if unsubscribed or expired
          }
        }
      });

      if (false && officialGroups.length) {
        // const realPlayerCount = players.filter(p => !p.bot).length;

        officialGroups.forEach(id => {
          console.log("aviso", id);
          telegram.sendMessage(
            id,
            `A game countdown has started in table ${table}, with ${players
              .map(p => p.name)
              .join(", ")}: https://qdice.wtf/${table}`
          );
          //sendScreenshot(id, table);
        });
      }
    }
  }
});

db.connect().then(db => {
  console.log("connected to postgres");
});

console.log("starting tg bot: ", process.env.BOT_TOKEN);
const bot = new Telegraf(process.env.BOT_TOKEN, { username: "quedice_bot" });

bot.catch(err => {
  console.log("Ooops", err);
});

bot.telegram.getMe().then(botInfo => {
  bot.options.username = botInfo.username;
});

bot.start(ctx => {
  console.log("started:", ctx.from);
  ctx.replyWithGame(gameShortName, markup);
});

bot.hears("que pasa", ctx => {
  ctx.reply("¡Qué Dice!");
});

const dice = ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"];
bot.hears(/tira.*dado/i, ctx =>
  ctx.reply(`Tirada de dado: ${dice[rand(1, 6) - 1]}`)
);

bot.command("dado", ctx => {
  const {
    text,
    from: { first_name: name },
  } = ctx.message;
  const roll = rand(1, 6);
  ctx.reply(`${name} ha tirado un: ${roll} ${dice[roll - 1]}`);
});
bot.command("dados", ctx => {
  const {
    text,
    from: { first_name: name },
  } = ctx.message;
  let amount = Math.min(30, parseInt(text.split("/dados ").pop(), 10));
  if (isNaN(amount)) {
    amount = 2;
  }
  const rolls = R.range(0, amount)
    .map(_ => rand(1, 6))
    .map(r => dice[r - 1])
    .join(" ");
  ctx.reply(`${name} ha tirado: ${rolls}`);
});

bot.on("sticker", ctx => ctx.reply("👍"));

bot.on("inline_query", ctx => {
  const result = [
    {
      //type: 'photo',
      //id: uid.randomUUID(16),
      //photo_url: 'https://quedice.host/assets/ThreeDice.jpg',
      //thumb_url: 'https://quedice.host/assets/ThreeDice_thumb.jpg',
      //title: `Tirada de dado: ${dice[rand(1, 6) - 1]}`,
      //caption: `Tirada de dado: ${dice[rand(1, 6) - 1]}`,
      type: "game",
      id: uid.randomUUID(16),
      game_short_name: "quedice",
      reply_markup: markup,
    },
  ];
  console.log(result);
  // Using shortcut
  ctx.answerInlineQuery(result);
});

const gameShortName = process.env.BOT_GAME;
//const gameUrl = 'http://lvh.me:5000';
const gameUrl =
  gameShortName === "QueDiceTest" ? "http://lvh.me:5000" : "https://qdice.wtf";

const markup = Extra.markup(
  Markup.inlineKeyboard([
    Markup.gameButton("🎲 Play in telegram!"),
    Markup.urlButton("Play in browser", gameUrl),
  ])
);
bot.command("game", ctx => {
  console.log("/game", gameShortName);
  ctx.replyWithGame(gameShortName, markup);
});

bot.gameQuery(ctx => {
  console.log("----------gameQuery", ctx.update.callback_query.message);
  db.getUserFromAuthorization(db.NETWORK_TELEGRAM, ctx.from.id)
    .then(user => {
      console.log("got user", user);
      if (user) {
        return user;
      }

      return telegram
        .getUserProfilePhotos(ctx.from.id, 0, 1)
        .then(({ photos: [[photo]] }) => {
          const { file_id } = photo;
          return telegram.getFile(file_id);
        })
        .then(({ file_path }) => {
          return `https://api.telegram.org/file/bot${process.env.BOT_TOKEN}/${file_path}`;
        })
        .catch(e => {
          console.error("could not get photo", e);
          return "https://telegram.org/img/t_logo.png";
        })
        .then(downloadAvatar(uid.randomUUID(16)))
        .then(filename => {
          console.log("create tg user", ctx.from);
          return db.createUser(
            db.NETWORK_TELEGRAM,
            ctx.from.id,
            ctx.from.first_name || ctx.from.username,
            null,
            `${process.env.PICTURE_URL_PREFIX}/${filename}`,
            {
              user_id: ctx.from.id,
              chat_id: ctx.chat.id,
              chat_type: ctx.chat.type,
              message_id: ctx.update.callback_query.message.message_id,
            }
          );
        });
    })
    .then(profile => {
      console.log("got profile", profile);
      const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET!);
      console.log("answer", gameUrl + "/token/" + token);
      return ctx.answerGameQuery(gameUrl + "/token/" + token);
    })
    .catch(e => {
      console.error("gameQuery error: " + e, e);
      telegram.sendMessage(
        ctx.chat.id,
        `Could not register user ${ctx.from.first_name || ctx.from.username}`
      );
    });
});

bot.startPolling();

const subscribed = [] as number[];
bot.command("notifyme", ctx => {
  const index = subscribed.indexOf(ctx.chat.id);
  if (index === -1) {
    subscribed.push(ctx.chat.id);
    ctx.reply("I will notify you when anyone joins a table.");
  } else {
    subscribed.slice(index, 1);
    ctx.reply("I will not notify you anymore.");
  }
});

module.exports.notify = string => {
  try {
  } catch (e) {
    console.error(e);
  }
};

const setScore = ({ user_id, chat_id, chat_type, message_id }, score) => {
  telegram
    .getGameHighScores(user_id, undefined, chat_id, message_id)
    .then(scores => {
      const playerScore = scores
        .filter(score => score.user.id === user_id)
        .shift();
      return playerScore ? playerScore.score : 0;
    })
    .catch(e => 0)
    .then(currentScore => {
      console.log(
        "setScore",
        JSON.stringify([
          user_id,
          chat_id,
          chat_type,
          message_id,
          currentScore + score,
        ])
      );
      return telegram.setGameScore(
        user_id,
        currentScore + score,
        undefined,
        chat_id,
        message_id,
        true,
        true
      );
    })
    .catch(e => console.error("setGameScore failed:", e));
};

bot.command("score", ctx => {
  console.log(ctx.message);
  telegram
    .getGameHighScores(
      ctx.from.id,
      undefined,
      ctx.chat.id,
      ctx.message.message_id
    )
    .then(scores => {
      ctx.reply(JSON.stringify(scores, null, "\n"));
    })
    .catch(e => ctx.reply("Error: " + e));
});

const downloadAvatar = id => url => {
  const filename = `user_${id}.jpg`;
  const file = fs.createWriteStream(
    path.join(process.env.AVATAR_PATH!, filename)
  );
  https.get(url, response => {
    response.pipe(file);
  });
  return filename;
};

bot.command("ss", async ctx => {
  sendScreenshot(ctx.chat.id, "");
});

let browserSingleton;
const newPage = async () => {
  if (!browserSingleton) {
    browserSingleton = await puppeteer.launch();
  }
  return browserSingleton.newPage();
};

const sendScreenshot = async (id, table) => {
  const page = await newPage();
  await page.setViewport({ width: 800, height: 600 });
  await page.goto(`https://qdice.wtf/${table}?screenshot`, {
    waitUntil: "networkidle2",
  });
  const image = await page.screenshot({});

  telegram.sendPhoto(id, {
    source: image,
  });
};

process.on("unhandledRejection", (reason, p) => {
  console.error("Unhandled Rejection at: Promise", p, "reason:", reason);
  // application specific logging, throwing an error, or other logic here
  throw reason;
});
