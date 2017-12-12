module Game.State exposing (..)

import Task
import Game.Types exposing (..)
import Types exposing (Model, Msg(..), User(Anonymous))
import Board
import Board.State
import Maps exposing (load)
import Land exposing (Color)
import Tables exposing (Table(..))
import Backend
import Backend.Types exposing (Topic(..))
import Helpers exposing (indexOf)


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
                        [ Backend.gameCommand model.backend table Enter
                        , Backend.publish <| TableMsg model.game.table <| Backend.Types.Leave <| Types.getUsername model
                        , Backend.publish <| TableMsg table <| Backend.Types.Join <| Types.getUsername model
                        ]

                    Nothing ->
                        []
    in
        ( { table = table
          , board = board
          , players = players
          , player = Nothing
          , status = Paused
          , playerSlots = 2
          , turnDuration = 10
          , turnIndex = -1
          , turnStarted = -1
          , chatInput = ""
          , chatBoxId = ("chatbox-" ++ toString table)
          }
        , cmds
        )


setter : Types.Model -> (Game.Types.Model -> Game.Types.Model) -> Types.Model
setter model setter =
    { model | game = (setter model.game) }


updateCommandResponse : Table -> PlayerAction -> Types.Model -> ( Types.Model, Cmd Msg )
updateCommandResponse table action model =
    model ! []


setTable : Game.Types.Model -> Table -> Game.Types.Model
setTable model table =
    let
        board =
            Board.init <| Tuple.first <| Maps.load table
    in
        { model | table = table, board = board }


updateTableStatus : Types.Model -> Game.Types.TableStatus -> ( Types.Model, Cmd Msg )
updateTableStatus model status =
    let
        game =
            model.game

        player =
            case model.user of
                Types.Anonymous ->
                    Nothing

                Types.Logged user ->
                    List.head <| List.filter (\p -> p.id == user.id) status.players

        hasTurn =
            case player of
                Nothing ->
                    False

                Just player ->
                    indexOf player status.players == status.turnIndex

        board_ =
            Board.State.updateLands model.game.board status.lands hasTurn

        game_ =
            { game
                | players = status.players
                , player = player
                , status = status.status
                , turnIndex = status.turnIndex
                , turnStarted = status.turnStarted
                , board = board_
            }
    in
        { model | game = game_ } ! []



--updateClickLand : Types.Model -> Land.Land -> Types.Model
--updateClickLand model land =
--model
