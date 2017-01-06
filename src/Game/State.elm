module Game.State exposing (init, update)

import Task
import Game.Types exposing (..)
import Types exposing (Model)
import Board
import Maps exposing (loadDefault)
import Land exposing (Color)
import Tables exposing (Table(..))
import Backend
import Backend.Types exposing (Topic(..))
import Material


init : ( Game.Types.Model, Cmd Game.Types.Msg )
init =
    let
        ( map, mapCmd ) =
            Maps.loadDefault

        board =
            Board.init map

        players =
            [ mkPlayer "El Chaqueta", mkPlayer "El Chocolate", mkPlayer "Carmen Amaya", mkPlayer "Sabicas" ]

        table =
            Melchor
    in
        ( Game.Types.Model table board players Paused ""
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
                    ! [ Backend.Types.Chat "anon" model.game.chatInput
                            |> Backend.Types.TableMsg model.game.table
                            |> Backend.publish
                      , Task.perform (always ClearChat) (always ClearChat) (Task.succeed ())
                      ]

            ClearChat ->
                let
                    game_ =
                        { game | chatInput = "" }
                in
                    { model | game = game_ } ! []
