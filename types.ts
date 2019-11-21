export type UserId = string;
export type Network = 'google' | 'password' | 'telegram' | 'reddit';
export type Emoji = string;
export type Timestamp = number;

export enum Color {
  Neutral = -1,
  Red = 1,
  Blue = 2,
  Green = 3,
  Yellow = 4,
  Magenta = 5,
  Cyan = 6,
  Orange = 7,
  Beige = 8,
  Black = 9,
}

export type TableProps = {
  readonly playerStartCount: number;
  readonly status: TableStatus;
  readonly gameStart: Timestamp;
  readonly turnIndex: number;
  readonly turnStart: Timestamp;
  readonly turnActivity: boolean;
  readonly turnCount: number;
  readonly roundCount: number;
  readonly attack: Attack | null;
};

export type Table = TableProps & {
  readonly name: string;
  readonly tag: string;
  readonly mapName: string;
  readonly adjacency: Adjacency;
  readonly stackSize: number;
  readonly noFlagRounds: number;
  readonly playerSlots: number;
  readonly startSlots: number;
  readonly points: number;

  readonly players: ReadonlyArray<Player>;
  readonly lands: ReadonlyArray<Land>;
  readonly watching: ReadonlyArray<Watcher>;
};

export type Land = {
  readonly emoji: Emoji;
  readonly cells: ReadonlyArray<{x: number; y: number; z: number}>;
  readonly color: Color;
  readonly points: number;
};

export type Attack = {
  start: Timestamp;
  from: Emoji;
  to: Emoji;
  clientId?: string;
};

export type TableStatus = 'PAUSED' | 'PLAYING' | 'FINISHED';

export type Adjacency = {
  readonly matrix: ReadonlyArray<ReadonlyArray<boolean>>;
  indexes: Readonly<{[index: string]: number}>;
};

type UserLike = {
  readonly id: UserId;
  readonly name: string;
  readonly picture: string;
  readonly level: number;
  readonly points: number;
};

export type User = UserLike & {
  readonly email: string;
  readonly networks: ReadonlyArray<string>;
  readonly claimed: boolean;
};

export type Player = UserLike & {
  readonly clientId: any;
  readonly color: Color;
  readonly reserveDice: number;
  readonly out: boolean;
  readonly outTurns: number;
  readonly points: number;
  readonly position: number;
  readonly score: number;
  readonly flag: any;
  readonly lastBeat: Timestamp;
  readonly ready: boolean;
  readonly bot: Persona | null;
};

export type Watcher = {
  clientId: any;
  id: UserId | null;
  name: string | null;
  lastBeat: number;
};

export type Elimination = {
  player: Player;
  position: number;
  reason: EliminationReason;
  source: {turns: number} | {player: Player; points: number};
};

export type EliminationReason = '☠' | '💤' | '🏆' | '🏳';

export class IllegalMoveError extends Error {
  userId?: UserId;
  emojiFrom?: Emoji;
  emojiTo?: Emoji;
  fromLand?: Land;
  toLand?: Land;

  constructor(
    message: string,
    userId?: UserId,
    emojiFrom?: Emoji,
    emojiTo?: Emoji,
    fromLand?: Land,
    toLand?: Land,
  ) {
    super(message);
    Object.setPrototypeOf(this, IllegalMoveError.prototype);
    this.userId = userId;
    this.emojiFrom = emojiFrom;
    this.emojiTo = emojiTo;
    this.fromLand = fromLand;
    this.toLand = toLand;
  }
}

export type CommandType =
  | 'Enter'
  | 'Exit'
  | 'Join'
  | 'Leave'
  | 'Attack'
  | 'EndTurn'
  | 'SitOut'
  | 'SitIn'
  | 'Chat'
  | 'ToggleReady'
  | 'Heartbeat'
  | 'Roll'
  | 'TickTurnOver'
  | 'TickTurnOut'
  | 'TickTurnAllOut'
  | 'TickStart'
  | 'CleanWatchers'
  | 'CleanPlayers';

export type CommandResult = {
  readonly type: CommandType;
  readonly table?: Partial<TableProps>;
  readonly lands?: ReadonlyArray<Land>;
  readonly players?: ReadonlyArray<Player>;
  readonly watchers?: ReadonlyArray<Watcher>;
  readonly eliminations?: ReadonlyArray<Elimination>;
};

export type Persona = {
  name: string;
};
