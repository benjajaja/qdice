module Game.State exposing (init, update)

import Game.Types exposing (Model, Msg(..))
import Types exposing (Model)
import Board
import Maps
import Land


-- import Board.Types exposing (Msg(..))


init : ( Game.Types.Model, Cmd Game.Types.Msg )
init =
    let
        ( map, mapCmd ) =
            Maps.loadDefault

        ( board, cmd ) =
            Board.init map

        -- (Land.fullCellMap 30 30 Land.Neutral)
    in
        ( (Game.Types.Model board)
        , Cmd.batch [ Cmd.map BoardMsg cmd, mapCmd ]
        )


update : Msg -> Types.Model -> ( Types.Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )
