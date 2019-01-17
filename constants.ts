export const STATUS_PAUSED = 'PAUSED';
export const STATUS_PLAYING = 'PLAYING';
export const STATUS_FINISHED = 'FINISHED';

export const TURN_SECONDS = 10;
export const ROLL_SECONDS = 1.0;
export const GAME_START_COUNTDOWN = 
  process.env.NODE_ENV === 'production'
    ? 30
    : 3;

export const COLOR_NEUTRAL = -1;
export const COLOR_RED = 1;
export const COLOR_BLUE = 2;
export const COLOR_GREEN = 3;
export const COLOR_YELLOW = 4;
export const COLOR_MAGENTA = 5;
export const COLOR_CYAN = 6;
export const COLOR_ORANGE = 7;
export const COLOR_BEIGE = 8;
export const COLOR_BLACK = 9;

export const COLORS = [
  COLOR_RED,
  COLOR_BLUE,
  COLOR_GREEN,
  COLOR_YELLOW,
  COLOR_MAGENTA,
  COLOR_CYAN,
  COLOR_ORANGE,
  COLOR_BEIGE,
  COLOR_BLACK,
];

export const ELIMINATION_REASON_DIE = '☠';
export const ELIMINATION_REASON_OUT = '💤';
export const ELIMINATION_REASON_WIN = '🏆';
export const ELIMINATION_REASON_SURRENDER = '🏳';

export const MAX_NAME_LENGTH = 20;

export const OUT_TURN_COUNT_ELIMINATION = 5;
