const Telegram = require('telegraf/telegram');
const telegram = new Telegram(process.env.BOT_TOKEN);
const Telegraf = require('telegraf');
const Extra = require('telegraf/extra');
const Markup = require('telegraf/markup');
const jwt = require('jsonwebtoken');
const ShortUniqueId = require('short-unique-id');
const R = require('ramda');
const { rand } = require('./rand');
const { userProfile } = require('./user');
const db = require('./db');

const uid = new ShortUniqueId();

require('./db').db().then(db => {
  console.log('connected to postgres');
});

console.log('starting tg bot: ', process.env.BOT_TOKEN);
const bot = new Telegraf(process.env.BOT_TOKEN, { username: 'quedice_bot' });

bot.catch((err) => {
  console.log('Ooops', err)
});

bot.telegram.getMe().then((botInfo) => {
  bot.options.username = botInfo.username;
});

bot.start((ctx) => {
  console.log('started:', ctx.from);
  ctx.replyWithGame(gameShortName, markup);
});

bot.hears('que pasa', (ctx) => {
  ctx.reply('¡Qué Dice!');
});

const dice = [ "⚀", "⚁", "⚂", "⚃", "⚄", "⚅", ];
bot.hears(/tira.*dado/i, (ctx) => ctx.reply(`Tirada de dado: ${dice[rand(1, 6) - 1]}`));

bot.command('dado', (ctx) => {
  const { text, from: { first_name : name } } = ctx.message;
  const roll = rand(1, 6);
  ctx.reply(`${name} ha tirado un: ${roll} ${dice[roll - 1]}`);
});
bot.command('dados', (ctx) => {
  const { text, from: { first_name : name } } = ctx.message;
  let amount = Math.min(30, parseInt(text.split('/dados ').pop(), 10));
  if (isNaN(amount)) {
    amount = 2;
  }
  const rolls = R.range(0, amount)
    .map(_ => rand(1, 6))
    .map(r => dice[r - 1])
    .join(' ');
  ctx.reply(`${name} ha tirado: ${rolls}`);
});

bot.on('sticker', (ctx) => ctx.reply('👍'));

bot.on('inline_query', (ctx) => {
  const result = [{
    //type: 'photo',
    //id: uid.randomUUID(16),
    //photo_url: 'https://quedice.host/assets/ThreeDice.jpg',
    //thumb_url: 'https://quedice.host/assets/ThreeDice_thumb.jpg',
    //title: `Tirada de dado: ${dice[rand(1, 6) - 1]}`,
    //caption: `Tirada de dado: ${dice[rand(1, 6) - 1]}`,
    type: 'game',
    id: uid.randomUUID(16),
    game_short_name: 'quedice',
    reply_markup: markup,
  }];
  console.log(result);
  // Using shortcut
  ctx.answerInlineQuery(result);
});


const gameShortName = process.env.BOT_GAME;
//const gameUrl = 'http://lvh.me:5000';
const gameUrl = gameShortName === 'QueDiceTest'
  ? 'http://lvh.me:5000'
  : 'https://quedice.host';

const markup = Extra.markup(
  Markup.inlineKeyboard([
    Markup.gameButton('🎲 Play now!'),
    Markup.urlButton('Play in browser', 'http://quedice.host')
  ])
);
bot.command('game', ctx => {
  console.log('/game', gameShortName);
  ctx.replyWithGame(gameShortName, markup);
});

bot.gameQuery(ctx => {
  console.log('----------gameQuery', ctx.update.callback_query.message);
  telegram.getUserProfilePhotos(ctx.from.id, 0, 1)
  .then(({ photos: [ [ photo ] ] }) => {
    const { file_id } = photo;
    return telegram.getFile(file_id);
  })
  .then(({ file_path }) => {
    return `https://api.telegram.org/file/bot${process.env.BOT_TOKEN}/${file_path}`;
  })
  .catch(e => {
    console.error('could not get photo', e);
    return 'https://telegram.org/img/t_logo.png';
  })
  .then(url => {
		return db.getUserFromAuthorization(db.NETWORK_TELEGRAM, ctx.from.id)
		.then(user => {
			console.log('got user', user);
			if (user) {
				return user;
			}
      console.log('create tg user', ctx.from);
			return db.createUser(db.NETWORK_TELEGRAM,
				ctx.from.id,
				ctx.from.first_name || ctx.from.username,
				null,
				url,
				{
					user_id: ctx.from.id,
					chat_id: ctx.chat.id,
					chat_type: ctx.chat.type,
					message_id: ctx.update.callback_query.message.message_id,
				}
			);
		});
  })
  .then(userProfile)
  .then(profile => {
    console.log('got profile', profile);
    const token = jwt.sign(JSON.stringify(profile), process.env.JWT_SECRET);
    return ctx.answerGameQuery(gameUrl + '/#token/' + token);
  })
  .catch(e => {
    console.error('gameQuery error: ' + e, e);
  });
});

bot.startPolling();

const subscribed = [ /*208216602*/ ];
bot.command('notifyme', ctx => {
  const index = subscribed.indexOf(ctx.chat.id);
  if (index === -1) {
    subscribed.push(ctx.chat.id);
    ctx.reply('Te voy a dar notificationes!');
  } else {
    subscribed.slice(index, 1);
    ctx.reply('Ya no estas suscrito.');
  }
});


module.exports.notify = string => {
  try {
  } catch (e) {
    console.error(e);
  }
};

const setScore = ({ user_id, chat_id, chat_type, message_id }, score) => {
  telegram.getGameHighScores(user_id, undefined, chat_id, message_id)
  .then(scores => {
    const playerScore = scores.filter(score => score.user.id === user_id).shift();
    return playerScore ? playerScore.score : 0;
  })
  .catch(e => 0)
  .then(currentScore => {
    console.log('setScore', JSON.stringify([user_id, chat_id, chat_type, message_id, currentScore + score]));
    return telegram.setGameScore(user_id, currentScore + score, undefined, chat_id, message_id, true, true);
  })
  .catch(e => console.error('setGameScore failed:', e));
};

bot.command('score', ctx => {
  console.log(ctx.message)
  telegram.getGameHighScores(ctx.from.id, undefined, ctx.chat.id, ctx.message.message_id)
  .then(scores => {
    ctx.reply(JSON.stringify(scores, null, '\n'));
  }).catch(e => ctx.reply('Error: ' + e));
});

let client;
module.exports.setMqtt = client_ => {
  client = client_;
  client.subscribe('events');
  client.on('message', (topic, message) => {
    if (topic === 'events') {
      const event = JSON.parse(message);
      switch (event.type) {
        case 'join':
          subscribed.forEach(id =>
            telegram.sendMessage(id, `${event.player.name} joined ${event.table}`)
            .catch(e => console.error(e)));
          break;
        case 'elimination':
          const { table, player, position, score } = event;
          if (player.telegram) {
            setScore(player.telegram, score);
          }
          break;
      }
    }
  });
};

