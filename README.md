# Qdice.wtf - a multiplayer strategy board game

[Qdice.wtf](https://qdice.wtf) is based off kdice which is based off dicewars.jp, a simplified Risk.

Qdice.wtf was built with the goal of learning the [Elm](http://elm-lang.org)
programming language, while also pushing the limits of product development to
the end. There is no monetization on the horizon, it's a pure hobby project.

## Technology

* Elm on the frontend
* Node.js with TypeScript on the backend
* MQTT as message broker
* Docker for deployments and e2e testing

## Architecture

The frontend part in Elm stems off my very first steps with Elm, so there is
some cruft for sure. On the other hand Elm allows for extreme refactors with
enormous confidence.

Server has gone through different phases. The first prototype used a primitive
OOP spaghetti style with in-memory storage.  
The second (worst) phase was still OOP spaghetti but with one node.js process
per table/game. The idea was that if one game crashes, it would not take the
others down. This was a terrible idea: a crash still aborts a particular game,
and there weren't any simultaneous games anyway. Also memory usage was huge.  
The third and current phase is an almost fully immutable functional style, with
PostgreSQL as storage. Runtime crashes are successfully recovered without
noticeable interruption to players, also thanks to using MQTT as broker.  
Future tech: rewrite in something exciting like Haskell or Erlan.

## Running locally

Copy `env_sample` to `.env`, and some values - you'll want at least the
following:
```
JWT_SECRET=anything
MQTT_PASSWORD=anything
POSTGRES_PASSWORD=anything
EMQX_DASHBOARD_PASSWORD=anything
VAPID_PUBLIC_KEY=run it once and let it generate some for you
VAPID_PRIVATE_KEY=you can get them from the logs: docker-compose logs nodice
```
The above values should be good enough for a local instance.
The VAPID keys will be generated and logged, if missing.

### As docker image

Run `./scripts/build.sh` to build a local `bgrosse/qdice:backend` image.

Run `./scripts/build.frontend.sh local` to build a local `bgrosse/qdice:fronted-local` image.

Run `./scripts/dev-env.sh` or take a look at that script.

### Full dev cycle

A full dev cycle only relies on docker for PostgreSQL and emqx, but needs
node.js installed on the system. We use `nodenv` as version manager, install
that and run `nodenv install` in the project, or use your version manager of
choice with the version in `.node-version`. My yarn version is `1.21.1`.

Run `yarn` and then `yarn generate-maps`. Then do the same inside `edice` and
additionally `yarn generate-changelog`.

Run `yarn start` inside `edice` to get a dev webserver that reload on Elm code
changes.

Get docker containers up with `./local_docker.sh`, subsequent restarts can be
done with `./local_env.sh`. This runs the node.js game server, there is no
autoreload so kill it with `Ctrl-C` and rerun the command when needed.

Open `http://localhost:5000`.

Some unit tests can be run with `yarn test` in the root and `edice` each.
There is `./scripts/CI.sh` which will build and run some basic end-to-end tests
against the real docker images (locally), and then deploy. You can ignore the
last part and just see the e2e tests with that.

## Game API

It is possible to connect to the game server over HTTP and MQTT.

## HTTP API

#### `/global`

Returns global configuration and table list and a top-10 of the leaderboard.

#### `/register`

Create an account with a payload like

```{id: "💩", name: "El Zorro", email: null, picture: ""}```

only `name` is relevant. Response is `text/plain` with a JWT. The JWT must be
used for all endpoints that need authentication with a header:
`authorization: Bearer <the jwt token>`.

You an get your userId from the `/me` endpoint with the JWT.

#### `/me`

Returns an array of `[user, token, push-subscriptions]`. The user has an `id`
field, the token should be stored in place of the previous token.

#### TODO: document remaining endpoints

## MQTT

The MQTT game state messages are quite reactive (maybe not 100%). After a client
sends its `enter` command to a table, it gets the full game state once. After
that it will get small deltas of game events like move, roll, elimination, etc.
Still some events might trigger a full game-update, although this should be
refactored.

### MQTT API incoming

You must subscribe to some topics, and publish to some others. You use a
clientId in the connection options, this is used througout the MQTT API.

#### `clients`

Some messages for all clients.

##### `{type:"tables, payload: ... }` info about ongoing games, see [Decoding.elm](edice/src/Backend/Decoding.elm#L307)

#### `clients/<clientId>`

##### {type:"user", payload: [<user record, <new token>]}

When your user's points, level, etc. change.

#### `tables/<table>/clients`

Game events are published here. Format is `{type,payload}`.

##### `chat` with message.

##### `enter`, `exit` with name.

##### `update` with full game state.

See [Decoding.elm](edice/src/Backend/Decoding.elm#L121)

##### `move` with attack move

payload is `{from:"<emoji>", to:"<emoji>"}`

##### `roll` with dice roll result

payload is `{from:[4,3],to:[3,6,1],turnStart:<timestamp>,players:...}`.

`from`/`to` are an array of dice rolls per each dice (points) of
attacker/defender.  `turnStart` is the turn reset. `players` is the updated list
of players due with updated land count etc.

##### `elimination` with player, position, score, reason

##### `receive` is dice give-out with player and count

Contains the player with updated dicecount

##### `join` and `leave` with player

### MQTT API outgoing

See `parseMessage` and `command` in [table.ts](table.ts#L155).

