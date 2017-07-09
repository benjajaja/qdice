module Game.State exposing (init, update, setTable)

import Task
import Game.Types exposing (..)
import Types exposing (Model)
import Board
import Maps exposing (load)
import Land exposing (Color)
import Tables exposing (Table(..))
import Backend
import Backend.Types exposing (Topic(..))
import Material


init : Table -> ( Game.Types.Model, Cmd Game.Types.Msg )
init table =
    let
        ( map, mapCmd ) =
            Maps.load table

        board =
            Board.init map

        players =
            [ mkPlayer "El Chaqueta", mkPlayer "El Chocolate", mkPlayer "Carmen Amaya", mkPlayer "Sabicas" ]
    in
        ( Game.Types.Model table board players Paused "" ("chatbox-" ++ toString table)
        , mapCmd
        )


mkPlayer : String -> Player
mkPlayer name =
    Player name Land.Neutral


update : Msg -> Types.Model -> ( Types.Model, Cmd Msg )
update msg model =
    let
        game =
            model.game
    in
        case msg of
            ChangeTable table ->
                let
                    game_ =
                        { game | table = table }
                in
                    { model | game = game_ } ! []

            BoardMsg boardMsg ->
                let
                    ( board, boardCmd ) =
                        Board.update boardMsg model.game.board

                    game_ =
                        { game | board = board }
                in
                    { model | game = game_ } ! [ Cmd.map BoardMsg boardCmd ]

            InputChat text ->
                let
                    game_ =
                        { game | chatInput = text }
                in
                    { model | game = game_ } ! []

            SendChat string ->
                model
                    ! [ Backend.Types.Chat (Types.getUsername model) model.game.chatInput
                            |> Backend.Types.TableMsg model.game.table
                            |> Backend.publish
                      , Task.perform (always ClearChat) (Task.succeed ())
                      ]

            ClearChat ->
                let
                    game_ =
                        { game | chatInput = "" }
                in
                    { model | game = game_ } ! []


setTable : Game.Types.Model -> Table -> Game.Types.Model
setTable model table =
    let
        board =
            Board.init <| Tuple.first <| Maps.load table
    in
        { model | table = table, board = board }
