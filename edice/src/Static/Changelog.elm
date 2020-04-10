module Static.Changelog exposing (fetchChangelog, view)

import Backend.HttpCommands
import Html exposing (..)
import Markdown
import Types exposing (..)


view : Model -> Html Msg
view model =
    case model.changelog of
        ChangelogFetching ->
            div [] [ text "Fetching changelog..." ]

        ChangelogFetched changelog ->
            Markdown.toHtml [] changelog

        ChangelogError err ->
            div [] [ text <| "Fetch error: " ++ err ]


fetchChangelog : Model -> ( Model, Cmd Msg )
fetchChangelog model =
    ( { model | changelog = ChangelogFetching }, Backend.HttpCommands.changelog model.backend )
