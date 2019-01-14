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
  readonly turnStarted: number;
  readonly turnActivity: boolean;
  readonly lands: ReadonlyArray<Land>
  readonly turnCount: number;
  readonly roundCount: number;
  readonly watching: ReadonlyArray<Watcher>;
}

export type Land = {
  readonly emoji: Emoji;
  readonly cells: ReadonlyArray<{ x: number, y: number, z: number }>;
  readonly color: Color;
  readonly points: number;
};

export type Emoji = string;
export type TableStatus = typeof STATUS_FINISHED | typeof STATUS_PLAYING | typeof STATUS_PAUSED;
export type Color
  = typeof COLOR_RED
  | typeof COLOR_BLUE
  | typeof COLOR_GREEN
  | typeof COLOR_YELLOW
  | typeof COLOR_MAGENTA
  | typeof COLOR_CYAN
  | typeof COLOR_ORANGE
  | typeof COLOR_BEIGE
  | typeof COLOR_BLACK

export type Adjacency = {
  readonly matrix: ReadonlyArray<ReadonlyArray<bool>>;
  indexes: Readonly<{ [index:Emoji]: number }>;
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

