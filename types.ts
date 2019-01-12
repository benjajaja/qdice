export type UserId = number
export type Network = 'google' | 'password' | 'telegram';

export type Table = {
  readonly name: string;
  readonly tag: string;
  readonly players: ReadonlyArray<Player>;
  readonly playerSlots: number;
  readonly startSlots: number;
  readonly points: number;
  readonly status: typeof STATUS_FINISHED | typeof STATUS_PLAYING | typeof STATUS_PAUSED;
  readonly gameStart: number;
  readonly turnIndex: number;
  readonly turnStarted: number;
  readonly turnActivity: boolean;
  readonly lands: ReadonlyArray<Land>
  readonly stackSize: number;
  readonly playerStartCount: number;
  readonly turnCount: number;
  readonly roundCount: number;
  readonly noFlagRounds: number;
  readonly watching: ReadonlyArray<Watcher>;
}

export type Land = any

export type Player = {
  readonly id: UserId;
  readonly clientId: any;
  readonly name: string;
  readonly picture: string;
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

export type Watcher = { clientId: any, name: string | null, lastBeat: number }

