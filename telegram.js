const Telegram = require('telegraf/telegram');
const telegram = new Telegram(process.env.BOT_TOKEN);
const Telegraf = require('telegraf');
const Extra = require('telegraf/extra');
const Markup = require('telegraf/markup');
const jwt = require('jsonwebtoken');
const ShortUniqueId = require('short-unique-id');
const R = require('ramda');
const { rand } = require('./rand');

const uid = new ShortUniqueId();

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

bot.command('help', (ctx) => ctx.reply('Try send a sticker!'));
bot.hears('que pasa', (ctx) => ctx.reply('¡Qué Dice!'));
const dice = [ "⚀", "⚁", "⚂", "⚃", "⚄", "⚅", ];
bot.hears(/tira.*dado/i, (ctx) => ctx.reply(`Tirada de dado: ${dice[rand(1, 6) - 1]}`));

bot.command('dado', (ctx) => {
  const { text, from: { first_name : name } } = ctx.message;
  const roll = rand(1, 6);
  ctx.reply(`${name} ha tirado un: ${roll} ${dice[roll - 1]}`);
});
bot.command('dados', (ctx) => ){
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


const gameShortName = 'QueDice';
//const gameUrl = 'http://lvh.me:5000';
const gameUrl = 'https://quedice.host';

const markup = Extra.markup(
  Markup.inlineKeyboard([
    Markup.gameButton('🎲 Play now!'),
    Markup.urlButton('Play in browser', 'http://quedice.host')
  ])
);
bot.command('game', ctx => {
  ctx.replyWithGame(gameShortName, markup);
});
bot.gameQuery(ctx => {
  console.log(ctx.from);
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
    console.log('telegram token', ctx.from);
    const token = jwt.sign({
      id: 'telegram_' + ctx.from.id,
      name: ctx.from.first_name || ctx.from.username || 'Mr. Telegram',
      email: '',
      picture: url,
    }, process.env.JWT_SECRET);
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
    console.log('sendCopy', subscribed, string);
    subscribed.forEach(id => telegram.sendMessage(id, string)
      .catch(e => console.error(e)));
  } catch (e) {
    console.error(e);
  }
};

module.exports.setScore = () => {
  //telegram.setGameScore(
};
