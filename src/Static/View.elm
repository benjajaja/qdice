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

#### Priority-High:
  * ✗ Update table list on local and other game update
  * ✗ Profile page
  * ✗ Login with facebook, github, reddit
  * ✗ Connect an auth method to anonymous account

#### Priority-Low:
  * ✗ Fullscreen tooltip
  * ✗ Show "who's turn it is" better
  * ✗ Attack animation
  * ✗ Replay a game
"""
