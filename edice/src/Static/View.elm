module Static.View exposing (view)

import Html exposing (..)
import Markdown
import Static.Help
import Types exposing (..)


view : Model -> StaticPage -> Html Msg
view model page =
    case page of
        Help ->
            Static.Help.markdown

        About ->
            Markdown.toHtml [] """
## About Qdice

A dice game, written in [Elm](https://elm-lang.org). A simplified Risk, inspired by [dicewars](http://www.gamedesign.jp/games/dicewars/) and its successor.

Created by <ste3ls@gmail.com>.

Continuous Integration: ![CircleCI](https://circleci.com/bb/easy-rider/nodice-server.svg?style=svg&circle-token=2e6482333d4ab9f6553381e0bfb152e93a43f9fc)

There is a [subreddit in place as a community forum](https://reddit.com/r/qdice), if you post there it will be seen by the site's owner.

## Roadmap

#### High priority:
  * ✗ Surrender / flag out

#### Medium priority:
  * ✗ Spread out initial positions
  * ✗ Water connections
  * ✗ Gamerule: Fog of war
  * ✗ Gamerule: Movement turn
  * ✗ Gamerule: Bastionize land
  * ✗ Gamerule: Ships on water connections
  * ✗ Gamerule: Capitols

### Low priority:
  * ✗ Profile page
  * ✗ Login with password, twitter, facebook, github
  * ✗ Replay a game

#### Complete:
  * ✔ Fix telegram bot
  * ✔ Connect an auth method to anonymous account
  * ✔ Delete account
  * ✔ Flag "ready" to start
  * ✔ Bots
  * ✔ Fullscreen tooltip
  * ✔ Set password on account
  * ...
"""
