import { TableStatus, Color, EliminationReason } from "./types";

export const STATUS_PAUSED: TableStatus = "PAUSED";
export const STATUS_PLAYING: TableStatus = "PLAYING";
export const STATUS_FINISHED: TableStatus = "FINISHED";

export const TURN_SECONDS = 20;
export const ROLL_SECONDS = 0.5;
export const GAME_START_COUNTDOWN = 5;

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

export const ELIMINATION_REASON_DIE: EliminationReason = "☠";
export const ELIMINATION_REASON_OUT: EliminationReason = "💤";
export const ELIMINATION_REASON_WIN: EliminationReason = "🏆";
export const ELIMINATION_REASON_SURRENDER: EliminationReason = "🏳";

export const MAX_NAME_LENGTH = 20;

export const OUT_TURN_COUNT_ELIMINATION = 2;

export const BOT_DEADLOCK_MAX = 10;
