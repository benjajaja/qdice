module Static.View exposing (view)

import Comments
import Html exposing (..)
import Markdown
import Static.Help
import Types exposing (..)


view : Model -> StaticPage -> Html Msg
view model page =
    div []
        [ case page of
            Help ->
                Static.Help.markdown

            About ->
                Markdown.toHtml [] """
## About Qdice

A dice game, written in [Elm](https://elm-lang.org). A simplified Risk, inspired by [dicewars](http://www.gamedesign.jp/games/dicewars/) and its successors.

Created by <ste3ls@gmail.com>.

## Forums

  * [Qdice reddit](https://www.reddit.com/r/Qdice/) to post any questions or opinion
  * [Discord](https://discord.gg/E2m3Gra) to chat with fellow players
  * [@qdicewtf](https://twitter.com/qdicewtf) same as with reddit
  * [github](https://github.com/gipsy-king/qdice) same as with reddit

## Development

Qdice is **Free Open Source Software**! See repo here: [github.com/gipsy-king/qdice](https://github.com/gipsy-king/qdice).

Before making a PR, I suggest to get in contact with me however you want, an issue in github is a good start.

## Tech rundown

* **Elm** - the main motivation was to learn [Elm](https://elm-lang.org). It's an awesome project
  that is quite different from conventional "enterprise" web development. Simply fun!
* **Node.js** - This has been quite a ride since the first prototype.
  1. First there was the most simple imperative mutable OOP style, with all games in memory.
     The problem was that when it eventually crashed, any games were aborted.
  2. Next iteration had one process per game, with the game in-memory, with a more
     functional immutable type code-style. The idea was that if one game crashes, it shouldn't
     affect other running games. This turned out to be terrible: total memory usage was huge
     and a game was still lost if a server crashed anyway.
  3. Current iteration is the standard node.js way, with all state in DB. Actually there is an
     in-memory cache layer, but a game will resume fine on a crash or restart.
  There is some sort of command-queue for processing all game events, both from players
  and from internal ticks.
* **MQTT** - with emqx. Web clients talk to the server over MQTT. The advantages are that there is a broker between
  client and server, so if the (node.js) server eventually crashes (and resurrects), clients don't even notice. Some
  "topic" concept is also provided. It's probably a bit overkill, because clients don't talk to each
  other.
* **PostgreSQL** - Solid relational database with good support for JSON columns when needed.
* **Docker** - everything is built and run with docker.
* **Testing** - Elm needs much less unit tests due to it's guarantees, there is much more benefit in
  having end-to-end tests where unit tests would be too cumbersome and overblown.
  End-to-end tests are run with docker and play a real game from beginning to end.
  The node.js server has a greater number of unit tests.
* **CI/CD** - Everything is continuosly deployed in a _build -> unit test -> end-to-end test_ pipeline.
"""
        , Comments.view model.zone model.user model.comments <| Comments.staticComments page
        ]
