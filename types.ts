export type UserId = number
export type Network = 'google' | 'password' | 'telegram';

export type Table = {
  readonly name: string;
  readonly tag: string;
  readonly mapName: string;
  readonly adjacency: Adjacency;
  readonly stackSize: number;
  readonly noFlagRounds: number;
  readonly playerSlots: number;
  readonly startSlots: number;
  readonly points: number;

  readonly playerStartCount: number;
  readonly players: ReadonlyArray<Player>;
  readonly status: TableStatus;
  readonly gameStart: number;
  readonly turnIndex: number;
  readonly turnStart: number;
  readonly turnActivity: boolean;
  readonly lands: ReadonlyArray<Land>
  readonly turnCount: number;
  readonly roundCount: number;
  readonly watching: ReadonlyArray<Watcher>;
  readonly attack: Attack | null;
}

export type Land = {
  readonly emoji: Emoji;
  readonly cells: ReadonlyArray<{ x: number, y: number, z: number }>;
  readonly color: Color;
  readonly points: number;
};

export type Attack = {
  start: number;
  from: Emoji;
  to: Emoji;
  clientId: string;
}

export type Emoji = string;
export enum TableStatus {
  Paused = 'PAUSED',
  Playing = 'PLAYING',
  Finished = 'FINISHED',
}

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

export type Adjacency = {
  readonly matrix: ReadonlyArray<ReadonlyArray<boolean>>;
  indexes: Readonly<{ [index: string]: number }>;
};

export type UserLike = {
  readonly id: UserId;
  readonly name: string;
  readonly clientId: any;
  readonly picture: string;
};

export type Player = UserLike & {
  readonly color: Color;
  readonly reserveDice: number;
  readonly out: boolean;
  readonly outTurns: number;
  readonly points: number;
  readonly level: number;
  readonly position: number;
  readonly score: number;
  readonly flag: any;
}

export type User = UserLike & {
}

export type Watcher = { clientId: any, name: string | null, lastBeat: number }

export class IllegalMoveError extends Error {
    constructor(message: string, user: User, emojiFrom?: Emoji, emojiTo?: Emoji, fromLand?: Land, toLand?: Land) {
        super(message);
        Object.setPrototypeOf(this, IllegalMoveError.prototype);
    }
}

