module Game.State exposing (..)

import Task
import Game.Types exposing (..)
import Types exposing (Model, Msg(..), User(Anonymous))
import Board
import Board.State
import Board.Types
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

        hadTurn =
            hasTurn player game.players game.turnIndex

        hasLostTurn =
            hadTurn == True && (hasTurn player status.players status.turnIndex) == False

        move =
            if hasLostTurn then
                Just Board.Types.Idle
            else
                Nothing

        board_ =
            Board.State.updateLands model.game.board status.lands move

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


showRoll : Types.Model -> Roll -> ( Types.Model, Cmd Msg )
showRoll model roll =
    let
        board_ =
            Board.State.updateLands model.game.board [] <| Just Board.Types.Idle

        game =
            model.game

        game_ =
            { game | board = board_ }
    in
        ( { model | game = game_ }, Cmd.none )


hasTurn : Maybe Player -> List Player -> Int -> Bool
hasTurn player players turnIndex =
    case player of
        Nothing ->
            False

        Just player ->
            indexOf player players == turnIndex


clickLand : Types.Model -> Land.Land -> ( Types.Model, Cmd Types.Msg )
clickLand model land =
    let
        canMove =
            hasTurn model.game.player model.game.players model.game.turnIndex

        ( move, cmd ) =
            if not canMove then
                ( model.game.board.move, Cmd.none )
            else
                case model.game.board.move of
                    Board.Types.Idle ->
                        ( Board.Types.From land, Cmd.none )

                    Board.Types.From from ->
                        let
                            gameCmd =
                                Backend.attack model.backend model.game.table from.emoji land.emoji
                        in
                            ( Board.Types.FromTo from land, gameCmd )

                    Board.Types.FromTo from to ->
                        ( model.game.board.move, Cmd.none )

        game =
            model.game

        board =
            game.board

        board_ =
            { board | move = move }

        game_ =
            { game | board = board_ }
    in
        { model | game = game_ } ! [ cmd ]



--updateClickLand : Types.Model -> Land.Land -> Types.Model
--updateClickLand model land =
--model
