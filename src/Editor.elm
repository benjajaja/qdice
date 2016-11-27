module Editor exposing (..)

import Html
import Html.App
import Dict
import Board
import Board.Types exposing (Msg(..))
import Land exposing (Land)


type Msg
    = BoardMsg Board.Msg


type alias Model =
    { board : Board.Model
    , selectedLands : List Land
    }


init : ( Model, Cmd Msg )
init =
    let
        ( board, cmd ) =
            Board.init
    in
        ( (Model board [])
        , Cmd.map BoardMsg cmd
        )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        BoardMsg boardMsg ->
            let
                ( board, boardCmd ) =
                    Board.update boardMsg model.board

                model =
                    case boardMsg of
                        ClickLand land ->
                            { model | selectedLands = land :: model.selectedLands }

                        _ ->
                            model
            in
                ( { model | board = board }, Cmd.map BoardMsg boardCmd )


view : Model -> Html.Html Msg
view model =
    Html.div []
        [ Html.div [] [ Html.text "Editor mode" ]
        , Html.App.map BoardMsg (Board.view model.board)
        ]


subscriptions : Model -> Sub Msg
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
