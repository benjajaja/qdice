exports.STATUS_PAUSED = 'PAUSED';
exports.STATUS_PLAYING = 'PLAYING';
exports.STATUS_FINISHED = 'FINISHED';

exports.TURN_SECONDS = 10;
exports.GAME_START_COUNTDOWN = 
  process.env.NODE_ENV === 'production'
    ? 30
    : 3;

exports.COLOR_NEUTRAL = -1;
exports.COLOR_RED = 1;
exports.COLOR_BLUE = 2;
exports.COLOR_GREEN = 3;
exports.COLOR_YELLOW = 4;
exports.COLOR_MAGENTA = 5;
exports.COLOR_CYAN = 6;
exports.COLOR_ORANGE = 7;
exports.COLOR_BEIGE = 8;
exports.COLOR_BLACK = 9;

exports.COLORS = [
  exports.COLOR_RED,
  exports.COLOR_BLUE,
  exports.COLOR_GREEN,
  exports.COLOR_YELLOW,
  exports.COLOR_MAGENTA,
  exports.COLOR_CYAN,
  exports.COLOR_ORANGE,
  exports.COLOR_BEIGE,
  exports.COLOR_BLACK,
];

exports.ELIMINATION_REASON_DIE = '☠';
exports.ELIMINATION_REASON_OUT = '💤';
exports.ELIMINATION_REASON_WIN = '🏆';

exports.MAX_NAME_LENGTH = 20;

exports.OUT_TURN_COUNT_ELIMINATION = 5;
