module Game.State exposing (..)

import Task
import Game.Types exposing (..)
import Types exposing (Model, Msg(..), User(Anonymous))
import Board
import Maps exposing (load)
import Land exposing (Color)
import Tables exposing (Table(..))
import Backend
import Backend.Types exposing (Topic(..))


init : Maybe Types.Model -> Table -> ( Game.Types.Model, List (Cmd Types.Msg) )
init model table =
    let
        ( map, mapCmd ) =
            Maps.load table

        board =
            Board.init map

        players =
            []

        cmds =
            mapCmd
                :: case model of
                    Just model ->
                        [ Backend.joinTable model.user table
                        , Backend.publish <| TableMsg model.game.table <| Backend.Types.Leave <| Types.getUsername model
                        , Backend.publish <| TableMsg table <| Backend.Types.Join <| Types.getUsername model
                        ]

                    Nothing ->
                        []
    in
        ( Game.Types.Model table board players Paused 2 "" ("chatbox-" ++ toString table)
        , cmds
        )


setter : Types.Model -> (Game.Types.Model -> Game.Types.Model) -> Types.Model
setter model setter =
    { model | game = (setter model.game) }


updateCommandResponse : Types.Model -> TableStatus -> ( Types.Model, Cmd Msg )
updateCommandResponse model result =
    model ! []


mkPlayer : String -> Player
mkPlayer name =
    Player name Land.Neutral


setTable : Game.Types.Model -> Table -> Game.Types.Model
setTable model table =
    let
        board =
            Board.init <| Tuple.first <| Maps.load table
    in
        { model | table = table, board = board }
