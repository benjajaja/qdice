export type UserId = number
export type Network = 'google' | 'password' | 'telegram';

export type Table = {
  readonly name: string;
  readonly tag: string;
  readonly mapName: string;
  readonly players: ReadonlyArray<Player>;
  readonly playerSlots: number;
  readonly startSlots: number;
  readonly points: number;
  readonly status: TableStatus;
  readonly gameStart: number;
  readonly turnIndex: number;
  readonly turnStarted: number;
  readonly turnActivity: boolean;
  readonly lands: ReadonlyArray<Land>
  readonly adjacency: Adjacency;
  readonly stackSize: number;
  readonly playerStartCount: number;
  readonly turnCount: number;
  readonly roundCount: number;
  readonly noFlagRounds: number;
  readonly watching: ReadonlyArray<Watcher>;
}

export type Land = {
  readonly emoji: Emoji;
  readonly cells: ReadonlyArray<{ x: number, y: number, z: number }>;
  readonly color: string;
  readonly points: number;
};

export type Emoji = string;
export type TableStatus = typeof STATUS_FINISHED | typeof STATUS_PLAYING | typeof STATUS_PAUSED;

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
  readonly color: string;
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

