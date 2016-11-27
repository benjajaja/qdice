module Editor.Editor exposing (..)

import Html
import Html.App
import Dict
import Material.Button as Button
import Material.Icon as Icon
import Editor.Types exposing (Msg(..), Model)
import Types
import Board
import Board.Types exposing (Msg(..))


init : ( Model, Cmd Editor.Types.Msg )
init =
    let
        ( board, cmd ) =
            Board.init 32 32
    in
        ( (Model board [])
        , Cmd.map BoardMsg cmd
        )


update : Editor.Types.Msg -> Model -> ( Model, Cmd Editor.Types.Msg )
update msg model =
    case msg of
        BoardMsg boardMsg ->
            let
                ( board, boardCmd ) =
                    Board.update boardMsg model.board

                model =
                    case boardMsg of
                        ClickLand land ->
                            { model | selectedLands = Debug.log "selected" (land :: model.selectedLands) }

                        _ ->
                            model
            in
                ( { model | board = board }, Cmd.map BoardMsg boardCmd )


view : Types.Model -> Html.Html Types.Msg
view model =
    let
        board =
            Html.App.map Types.EditorMsg (Html.App.map BoardMsg (Board.view model.editor.board))
    in
        Html.div []
            [ Html.div [] [ Html.text "Editor mode" ]
            , board
            , Button.render Types.Mdl
                [ 0 ]
                model.mdl
                [ Button.fab
                , Button.colored
                , Button.ripple
                  -- , Button.onClick MyClickMsg
                ]
                [ Icon.i "add" ]
            ]


subscriptions : Model -> Sub Editor.Types.Msg
subscriptions model =
    Board.subscriptions model.board |> Sub.map BoardMsg


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
