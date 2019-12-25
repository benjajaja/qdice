module Static.View exposing (view)

import Html exposing (..)
import Markdown
import Static.Changelog
import Static.Help
import Types exposing (..)


view : Model -> StaticPage -> Html Msg
view model page =
    case page of
        Help ->
            Static.Help.markdown

        Changelog ->
            Static.Changelog.markdown

        About ->
            Markdown.toHtml [] """
## About Qdice

A dice game, written in [Elm](https://elm-lang.org). A simplified Risk, inspired by [dicewars](http://www.gamedesign.jp/games/dicewars/) and its successor.

Created by <ste3ls@gmail.com>.

There is a [subreddit in place as a community forum](https://reddit.com/r/qdice), if you post there it will be seen by the site's owner.

## Roadmap

#### High priority:
  * (nothing at the moment)

#### Medium priority:
  * ✗ Lower flag to current position
  * ✗ Profile page
  * ✗ Auth does not always return to same table

### Low priority:
  * ✗ Unintented login change when adding already registered user of auth network
  * ✗ Upload avatar
  * ✗ Record and replay a game
  * ✗ Reset monthly leaderboard, give awards

### Considering:
  * ? Login with password, twitter, facebook, github
  * ? Spread out initial positions
  * ? Gamerule: Fog of war
  * ? Gamerule: Movement turn
  * ? Gamerule: Bastionize land
  * ? Gamerule: Ships on water connections
  * ? Gamerule: Capitols

#### Complete (also see [changelog](/changelog) for bug fixes):
  * ✔ Table list header/description
  * ✔ Redirect to best table
  * ✔ Gamerule: Water connections
  * ✔ Fixed laggy animations
  * ✔ Surrender / flag out
  * ✔ Fix telegram bot (needs verification)
  * ✔ Connect an auth method to anonymous account
  * ✔ Delete account
  * ✔ Flag "ready" to start
  * ✔ Bots
  * ✔ Fullscreen tooltip
  * ...
"""
