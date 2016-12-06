module Game.State exposing (init, update)

import Game.Types exposing (Model, Msg(..))
import Types exposing (Model)
import Board
import Maps


-- import Board.Types exposing (Msg(..))


init : ( Game.Types.Model, Cmd Game.Types.Msg )
init =
    let
        ( board, cmd ) =
            Board.init 35 35
    in
        ( (Game.Types.Model board)
        , Cmd.map BoardMsg cmd
        )


update : Msg -> Types.Model -> ( Types.Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )
