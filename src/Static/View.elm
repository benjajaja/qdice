module Static.View exposing (view, update)

import Types exposing (..)
import Html exposing (..)
import Markdown
import Material.Tabs as Tabs
import Material.Options as Options
import Material.Icon as Icon
import Static.Types
import Static.Help


view : Model -> StaticPage -> Html Msg
view model page =
    case page of
        Help ->
            Tabs.render Mdl
                []
                model.mdl
                [ Tabs.ripple
                , Tabs.onSelectTab (Static.Types.SelectTab >> StaticPageMsg)
                , Tabs.activeTab model.staticPage.help.tab
                ]
                [ Tabs.label
                    [ Options.center ]
                    [ text "English" ]
                , Tabs.label
                    [ Options.center ]
                    [ text "Español" ]
                ]
                [ Static.Help.markdown model.staticPage.help.tab ]

        About ->
            Markdown.toHtml [] """
## About *¡Qué Dice!*

A dice game, written in [Elm](https://elm-lang.org). A simplified Risk, inspired by [dicewars](http://www.gamedesign.jp/games/dicewars/) and its successor.

Created by <ste3ls@gmail.com>.

#### Roadmap:
  * ✓ Leaderboard
  * x Show who's turn it is better
  * x Show when it is your turn better
  * x Supermodal when you are out/away
  * x Flags
  * x Attack animation
  * x Heartbeat, remove player in game queue if not beating
  * x Profile page
  * x Save all board moves/events
  * x Replay a game
  * x Fix triple "X joined" message
  * x Login with facebook
  * x Login with github
"""


update : Model -> Static.Types.Msg -> ( Model, Cmd Msg )
update model msg =
    case msg of
        Static.Types.SelectTab idx ->
            let
                staticPage =
                    model.staticPage

                help =
                    staticPage.help
            in
                ( { model | staticPage = { staticPage | help = { help | tab = idx } } }, Cmd.none )
