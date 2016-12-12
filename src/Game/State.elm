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
    in
        ( (Game.Types.Model board)
        , Cmd.batch [ Cmd.map BoardMsg cmd, mapCmd ]
        )


update : Msg -> Types.Model -> ( Types.Model, Cmd Msg )
update msg model =
    case msg of
        BoardMsg boardMsg ->
            let
                ( board, boardCmd ) =
                    Board.update boardMsg model.game.board

                game =
                    { board = board }
            in
                ( { model | game = game }, Cmd.map BoardMsg boardCmd )



-- _ ->
--     ( model, Cmd.none )
