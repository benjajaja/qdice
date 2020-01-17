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

Check the sticky **[Development post](https://www.reddit.com/r/Qdice/comments/epy4hh/development_updates/)** on the subreddit that will be updated. You can post issues and wishes on that post or generally in the sub.

There is also the **[changelog](/changelog)** with a complete list of all changes that go live.
"""
