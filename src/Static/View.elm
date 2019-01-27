module Static.View exposing (view)

import Html exposing (..)
import Markdown
import Material.Icon as Icon
import Material.Options as Options
import Static.Help
import Types exposing (..)


view : Model -> StaticPage -> Html Msg
view model page =
    case page of
        Help ->
            Static.Help.markdown

        About ->
            Markdown.toHtml [] """
## About *¡Qué Dice!*

A dice game, written in [Elm](https://elm-lang.org). A simplified Risk, inspired by [dicewars](http://www.gamedesign.jp/games/dicewars/) and its successor.

Created by <ste3ls@gmail.com>.

#### Roadmap:
  * ✓ Leaderboard
  * ✓ Show who's turn it is better
  * ✓ Supermodal when you are out/away
  * ✓ Flags
  * ✓ Simple keyboard inside telegram
  * x Attack animation
  * x Heartbeat, remove player in game queue if not beating
  * x Profile page
  * x Save all board moves/events
  * x Replay a game
  * x Fix triple "X joined" message
  * x Login with facebook
  * x Login with github
"""
