const Telegram = require('telegraf/telegram');
const telegram = new Telegram(process.env.BOT_TOKEN);
const Telegraf = require('telegraf');
const Extra = require('telegraf/extra');
const Markup = require('telegraf/markup');
const jwt = require('jsonwebtoken');

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
bot.hears('hi', (ctx) => ctx.reply('Hey there!'));
bot.hears(/buy/i, (ctx) => ctx.reply('Buy-buy!'));
bot.on('sticker', (ctx) => ctx.reply('👍'));



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
    const token = jwt.sign({
      id: 'telegram_' + ctx.from.id,
      name: ctx.from.first_name || ctx.from.username || 'Mr. Telegram',
      email: '',
      picture: url,
    }, process.env.JWT_SECRET);
    ctx.answerGameQuery(gameUrl + '/#token/' + token);
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

