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

#### Priority-High:
  * ✗ Flag "ready" to start
  * ✗ Show "who's turn it is" better
  * ✗ Profile page
  * ✗ Set password on account, login with password
  * ✗ Connect an auth method to anonymous account

#### Priority-Low:
  * ✗ Fullscreen tooltip
  * ✗ Replay a game
  * ✗ Login with twitter, facebook, github
"""
