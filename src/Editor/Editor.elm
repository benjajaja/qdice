port module Editor.Editor exposing (..)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Editor.Types exposing (Msg(..), Model)
import Types
import Board
import Board.Types exposing (Msg(..))
import Land
import Maps
import Tables
import Markdown


port selectAll : String -> Cmd msg


init : ( Model, Cmd Editor.Types.Msg )
init =
    let
        board =
            Board.init (Land.fullCellMap 30 30 Land.Editor)

        ( map, _ ) =
            Maps.load Tables.Melchor

        board_ =
            { board | map = map }

        defaultEmojiMap =
            Maps.toCharList map
                |> List.map (String.join "")
                |> String.join "\n"
    in
        ( (Model board_ defaultEmojiMap), Cmd.none )


update : Editor.Types.Msg -> Model -> ( Model, Cmd Editor.Types.Msg )
update msg model =
    case msg of
        BoardMsg boardMsg ->
            let
                ( board, boardCmd ) =
                    Board.update boardMsg model.board

                newModel =
                    case boardMsg of
                        ClickLand land ->
                            let
                                map =
                                    model.board.map
                            in
                                { model
                                    | board = { board | map = map }
                                }

                        _ ->
                            { model | board = board }
            in
                ( newModel, Cmd.map BoardMsg boardCmd )

        RandomLandColor land color ->
            Land.setColor model.board.map land color |> updateMap model Cmd.none

        EmojiInput string ->
            let
                board =
                    model.board

                map =
                    Maps.emojisToMap <| "\n" ++ string
            in
                ( { model
                    | board = { board | map = map }
                  }
                , Cmd.none
                )


view : Types.Model -> Html.Html Types.Msg
view model =
    Html.div [ class "edEditor" ]
        [ div [] [ h2 [] [ Html.text "Editor" ] ]
        , div [] [ h4 [] [ Html.text "experimental feature 💥" ] ]
        , div []
            [ Board.view model.editor.board
                |> Html.map BoardMsg
            ]
        , textarea
            [ cols 30
            , rows 30
            , defaultValue model.editor.emojiMap
            , onInput EmojiInput
            ]
            []
        , Maps.symbols
            |> List.map text
            |> (::) (text "Land symbols: ")
            |> div []
        , div [] [ text "Space symbol: \"\x3000\"" ]
        , div [] [ text "Odd-line-start symbol: \"〿\"" ]
        , helpText
        ]
        |> Html.map Types.EditorMsg


renderSave : List (List String) -> List (Html.Html Editor.Types.Msg)
renderSave save =
    List.indexedMap
        (\row ->
            \line ->
                Html.div []
                    (List.indexedMap
                        (\col ->
                            \char ->
                                Html.div
                                    [ Html.Attributes.style
                                        [ ( "display", "inline-block" )
                                        , ( "width"
                                          , if row % 2 == 1 && col == 0 then
                                                "10px"
                                            else
                                                "20px"
                                          )
                                        ]
                                    ]
                                    [ Html.text char ]
                        )
                        line
                    )
        )
        save


updateMap : Model -> Cmd Editor.Types.Msg -> Land.Map -> ( Model, Cmd Editor.Types.Msg )
updateMap model cmd map =
    let
        { board } =
            model

        newModel =
            { model | board = { board | map = map } }

        debugCmd =
            Maps.consoleLogMap map
    in
        ( newModel, Cmd.batch [ cmd, debugCmd ] )


containsAny : List a -> List a -> Bool
containsAny a b =
    List.any (\a -> List.member a b) a


helpText : Html Editor.Types.Msg
helpText =
    Markdown.toHtml [] """
## How to use

Edit the text field above to create a map. Watch the live preview above to ensure that the result is as expected.

## Map format rules

1. Odd lines must start with the 〿 character. This way, even and odd lines match up as text.
2. Spaces horizontally before and between lands must be set with the unicode space \\u3000 (copy this inside the quotes: "\x3000"). That space is as wide as most emojis. This way, lands match up as text.
3. Land "cells" or "hexagons" must be represented with an emoji from the list shown above.
4. Any other character is not valid and will break a map.

## How is this useful? How can I play my map?

You cannot yet play your own creations. It is mostly intended for development.
"""
