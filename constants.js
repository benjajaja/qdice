exports.STATUS_PAUSED = 'PAUSED';
exports.STATUS_PLAYING = 'PLAYING';
exports.STATUS_FINISHED = 'FINISHED';

exports.TURN_SECONDS = 10;
exports.GAME_START_COUNTDOWN = 
  process.env.NODE_ENV === 'production'
    ? 30
    : 3;

exports.COLOR_NEUTRAL = -1;

exports.ELIMINATION_REASON_DIE = '☠';
exports.ELIMINATION_REASON_OUT = '💤';
exports.ELIMINATION_REASON_WIN = '🏆';

exports.MAX_NAME_LENGTH = 20;

exports.OUT_TURN_COUNT_ELIMINATION = 5;
