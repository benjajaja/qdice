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
## About *¡Qué Dice!*

A dice game, written in [Elm](https://elm-lang.org). A simplified Risk, inspired by [dicewars](http://www.gamedesign.jp/games/dicewars/) and its successor.

Created by <ste3ls@gmail.com>.

#### Roadmap 2019:
  * ✓ Cleaner UI
  * ✓ Landscape fullscreen mode in mobile
  * ✓ Stateless server, recovers on errors
  * ? Heartbeat, remove player in game queue if not beating
  * ✓ Fix error toast
  * ✗ Fix Account page, logout button
  * ✗ Fullscreen tooltip
  * ✗ Update table list
  * ✗ Show "who's turn it is" better
  * ✗ Attack animation
  * ✗ Profile page
  * ✗ Replay a game
  * ✗ Login with facebook
  * ✗ Login with github
"""
