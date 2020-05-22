import { TableStatus, Color, EliminationReason } from "./types";

export const STATUS_PAUSED: TableStatus = "PAUSED";
export const STATUS_PLAYING: TableStatus = "PLAYING";
export const STATUS_FINISHED: TableStatus = "FINISHED";

export const TURN_SECONDS = 20;
export const ROLL_SECONDS = 0.5;
export const ROLL_SECONDS_BOT = 0.2;
export const GAME_START_COUNTDOWN = 55;
export const GAME_START_COUNTDOWN_FULL = 5;

export const ELIMINATION_REASON_DIE: EliminationReason = "☠";
export const ELIMINATION_REASON_OUT: EliminationReason = "💤";
export const ELIMINATION_REASON_WIN: EliminationReason = "🏆";
export const ELIMINATION_REASON_SURRENDER: EliminationReason = "🏳";

export const MAX_NAME_LENGTH = 20;

export const OUT_TURN_COUNT_ELIMINATION = 2;

export const BOT_DEADLOCK_MAX = 10;

export const EMPTY_PROFILE_PICTURE = "assets/empty_profile_picture.svg";
