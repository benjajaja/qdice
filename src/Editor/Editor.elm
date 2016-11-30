port module Editor.Editor exposing (..)

import Html
import Html.App
import Html.Attributes
import Html.Events
import Dict
import String
import Material
import Material.Button as Button
import Material.Icon as Icon
import Editor.Types exposing (Msg(..), Model)
import Types
import Board
import Board.Types exposing (Msg(..))
import Land


port selectAll : String -> Cmd msg


init : ( Model, Cmd Editor.Types.Msg )
init =
    let
        ( board, cmd ) =
            Board.init 32 32
    in
        ( (Model Material.model board [] [ [] ])
        , Cmd.map BoardMsg cmd
        )


update : Editor.Types.Msg -> Model -> ( Model, Cmd Editor.Types.Msg )
update msg model =
    case msg of
        Mdl msg ->
            Material.update msg model

        BoardMsg boardMsg ->
            let
                ( board, boardCmd ) =
                    Board.update boardMsg model.board

                model =
                    case boardMsg of
                        ClickLand land ->
                            let
                                selectedLands =
                                    land :: model.selectedLands

                                map =
                                    (Land.landColor model.board.map land Land.EditorSelected
                                        |> Land.highlight False
                                    )
                                    <|
                                        land

                                -- mobile does mousedown on click, but not mouseup; quick & dirty fix
                            in
                                { model
                                    | selectedLands = selectedLands
                                    , board = { board | map = map }
                                }

                        _ ->
                            { model | board = board }
            in
                ( model, Cmd.map BoardMsg boardCmd )

        ClickAdd ->
            addSelectedLand model

        RandomLandColor land color ->
            Land.setColor model.board.map land color |> updateMap model Cmd.none

        ClickOutput id ->
            ( model, selectAll id )


view : Types.Model -> Html.Html Types.Msg
view model =
    let
        board =
            Board.view model.editor.board
                |> Html.App.map BoardMsg
                |> Html.App.map Types.EditorMsg
    in
        Html.div []
            [ Html.div [] [ Html.text "Editor mode" ]
            , board
            , Button.render
                Editor.Types.Mdl
                [ 0 ]
                model.mdl
                [ Button.fab
                , Button.colored
                , Button.ripple
                , Button.onClick ClickAdd
                ]
                [ Icon.i "add" ]
                |> Html.App.map Types.EditorMsg
            , Html.pre [ Html.Attributes.id "emoji-map", Html.Events.onClick <| ClickOutput "emoji-map" ] (renderSave model.editor.mapSave)
                |> Html.App.map Types.EditorMsg
            ]


subscriptions : Model -> Sub Editor.Types.Msg
subscriptions model =
    Board.subscriptions model.board |> Sub.map BoardMsg


renderSave : List (List Char) -> List (Html.Html Editor.Types.Msg)
renderSave save =
    List.indexedMap
        (\i ->
            \row ->
                Html.div [ Html.Attributes.style [ ( "position", "relative" ), ( "left", ((i % 2) * -10 |> toString) ++ "px" ) ] ]
                    (List.map
                        (\c ->
                            Html.div
                                [ Html.Attributes.style [ ( "display", "inline-block" ), ( "width", "20px" ) ]
                                ]
                                [ Html.text <| emojiCharToString c ]
                        )
                        (offsetCharRow row i)
                    )
        )
        save


emojiCharToString char =
    case char of
        ' ' ->
            "  "

        '\t' ->
            " "

        _ ->
            String.fromChar char


offsetCharRow row i =
    case i % 2 of
        1 ->
            '\t' :: row

        _ ->
            row


addSelectedLand : Model -> ( Model, Cmd Editor.Types.Msg )
addSelectedLand model =
    let
        { board } =
            model

        map =
            board.map

        selectedCells =
            List.map (\l -> l.hexagons) model.selectedLands
                |> List.concat

        filterSelection lands =
            List.filter (\l -> not <| containsAny l.hexagons selectedCells) lands

        newLand =
            Land.Land selectedCells Land.Editor False

        _ =
            Debug.log "fst" ( List.head map.lands, model.selectedLands )
    in
        updateMap
            { model | selectedLands = [] }
            (RandomLandColor
                newLand
                |> Land.randomPlayerColor
            )
            { map | lands = newLand :: (filterSelection map.lands) }


updateMap : Model -> Cmd Editor.Types.Msg -> Land.Map -> ( Model, Cmd Editor.Types.Msg )
updateMap model cmd map =
    let
        { board } =
            model

        newModel =
            { model | board = { board | map = map } }
    in
        ( { newModel | mapSave = mapElm map }, cmd )


containsAny : List a -> List a -> Bool
containsAny a b =
    List.any (\a -> List.member a b) a


mapElm : Land.Map -> List (List Char)
mapElm map =
    let
        lands =
            List.filter (\l -> l.color /= Land.Editor) map.lands
                |> List.reverse
    in
        case lands of
            [] ->
                [ [ ' ' ] ]

            hd :: _ ->
                List.map
                    (\row ->
                        let
                            cells : List Int
                            cells =
                                List.map (\col -> Land.at lands ( col, row )) [1..map.width]
                                    |> Debug.log "cells"
                        in
                            List.map
                                (\c ->
                                    let
                                        symbol =
                                            indexSymbol c
                                    in
                                        symbol
                                )
                                cells
                     -- |> List.map String.fromChar
                     -- |> String.join ""
                    )
                    [1..map.height]



-- |> String.join "\n"


symbolDict : Dict.Dict Int Char
symbolDict =
    List.indexedMap (,)
        [ '💩'
        , '🍋'
        , '🔥'
        , '😃'
        , '🐙'
        , '🐸'
        , '☢'
        , '😺'
        , '🐵'
        , '❤'
        , '🚩'
        , '🚬'
        , '🚶'
        , '💎'
        , '⁉'
        , '⌛'
        , '☀'
        , '☁'
        , '☕'
        , '🎩'
        , '♨'
        , '👙'
        , '⚠'
        , '⚡'
        , '⚽'
        , '⛄'
        , '⭐'
        , '🌙'
        , '🌴'
        , '🌵'
        , '🍀'
        , '💥'
        , '🍒'
        , '🍩'
        , '🍷'
        , '🍺'
        , '🍏'
        , '🎵'
        , '🐟'
        , '🐧'
        , '🐰'
        , '🍉'
        , '👀'
        , '👍'
        , '👑'
        , '👻'
        , '💊'
        , '💋'
        , '💣'
        , '💧'
        , '💀'
        , '🌎'
        , '🐊'
        , '✊'
        , '⛔'
        , '🍌'
        ]
        |> Dict.fromList


indexSymbol : Int -> Char
indexSymbol i =
    case Dict.get i symbolDict of
        Just c ->
            c

        Nothing ->
            ' '
