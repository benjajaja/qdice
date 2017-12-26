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
                    Maps.emojisToMap string
            in
                ( { model
                    | board = { board | map = map }
                  }
                , Cmd.none
                )


view : Types.Model -> Html.Html Types.Msg
view model =
    Html.div [ class "edEditor" ]
        [ div [] [ h1 [] [ Html.text "Editor" ] ]
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
