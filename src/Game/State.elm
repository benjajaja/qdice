port module Game.State exposing (..)

import Task
import Dom.Scroll exposing (..)
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
import Backend.MqttCommands exposing (gameCommand, attack)
import Helpers exposing (indexOf, playSound, pipeUpdates, find)


init : Maybe Types.Model -> Table -> ( Game.Types.Model, Cmd Types.Msg )
init model table =
    let
        ( map, mapCmd ) =
            Maps.load table

        board =
            Board.init map

        players =
            []
    in
        ( { table = table
          , board = board
          , players = players
          , player = Nothing
          , status = Paused
          , gameStart = Nothing
          , playerSlots = 0
          , turnIndex = -1
          , hasTurn = False
          , turnStarted = -1
          , chatInput = ""
          , chatLog = []
          , gameLog = [ LogBegin table ]
          , isPlayerOut = False
          , roundCount = 0
          , canFlag = False
          }
            |> (\m ->
                    case model of
                        Just model ->
                            updateGameInfo m model.tableList

                        Nothing ->
                            m
               )
        , mapCmd
        )


changeTable : Types.Model -> Table -> ( Types.Model, Cmd Types.Msg )
changeTable model table =
    let
        previousTable =
            model.game.table

        ( game, cmd ) =
            init (Just model) table

        model_ =
            { model | game = game }
    in
        ( model_, cmd )
            |> pipeUpdates Backend.subscribeGameTable table


findUserPlayer : Types.User -> List Player -> Maybe Player
findUserPlayer user players =
    case user of
        Types.Anonymous ->
            Nothing

        Types.Logged user ->
            List.head <| List.filter (\p -> p.id == user.id) players


updateTableStatus : Types.Model -> Game.Types.TableStatus -> ( Types.Model, Cmd Msg )
updateTableStatus model status =
    let
        game =
            model.game

        player : Maybe Player
        player =
            findUserPlayer model.user status.players

        hasChangedTurn : Maybe Player
        hasChangedTurn =
            if game.turnIndex /= status.turnIndex then
                List.drop status.turnIndex status.players |> List.head
            else
                Nothing

        hasTurn =
            case player of
                Nothing ->
                    False

                Just player ->
                    indexOf player status.players == status.turnIndex

        hasGainedTurn =
            case player of
                Nothing ->
                    False

                Just player ->
                    hasTurn && not game.hasTurn

        hasLostTurn =
            case player of
                Nothing ->
                    False

                Just player ->
                    not hasTurn && game.hasTurn

        isOut =
            case player of
                Nothing ->
                    False

                Just player ->
                    player.out

        move =
            if hasLostTurn then
                Just Board.Types.Idle
            else
                Nothing

        board_ =
            Board.State.updateLands model.game.board status.lands move

        hasStarted =
            game.status /= Playing && status.status == Playing

        hasFinished =
            game.status == Playing && status.status == Finished

        gameStart =
            case status.status of
                Playing ->
                    Nothing

                _ ->
                    case status.gameStart of
                        0 ->
                            Nothing

                        timestamp ->
                            Just timestamp

        canFlag =
            case player of
                Nothing ->
                    False

                Just player ->
                    status.canFlag
                        && player.gameStats.position
                        > 1
                        && case player.flag of
                            Just f ->
                                False

                            Nothing ->
                                True

        game_ =
            { game
                | players = status.players
                , player = player
                , status = status.status
                , gameStart = gameStart
                , turnIndex = status.turnIndex
                , hasTurn = hasTurn
                , turnStarted = status.turnStarted
                , isPlayerOut = isOut
                , board = board_
                , roundCount = status.roundCount
                , canFlag = canFlag
            }

        ( model_, turnChangeCmd ) =
            { model | game = game_ }
                |> (\m ->
                        case hasChangedTurn of
                            Just player ->
                                updateChatLog m <| LogTurn player.name player.color

                            Nothing ->
                                ( m, Cmd.none )
                   )
    in
        model_
            ! [ (if hasStarted then
                    Cmd.batch <|
                        Helpers.playSound "start"
                            :: (if hasTurn then
                                    [ Helpers.setFavicon "alert" ]
                                else
                                    []
                               )
                 else
                    Cmd.none
                )
              , (if hasFinished then
                    Cmd.batch
                        [ Helpers.playSound "finish"
                        , Helpers.setFavicon ""
                        ]
                 else
                    Cmd.none
                )
              , (if hasGainedTurn then
                    Cmd.batch
                        [ Helpers.playSound "turn"
                        , Helpers.setFavicon "alert"
                        ]
                 else
                    Cmd.none
                )
              , (if hasLostTurn then
                    Helpers.setFavicon ""
                 else
                    Cmd.none
                )
              , turnChangeCmd
              ]


updateGameInfo : Game.Types.Model -> List Game.Types.TableInfo -> Game.Types.Model
updateGameInfo model tableList =
    let
        currentTableInfo =
            tableList
                |> List.filter (\t -> t.table == model.table)
                |> List.head
    in
        case currentTableInfo of
            Just tableInfo ->
                { model | playerSlots = tableInfo.playerSlots }

            Nothing ->
                model


showRoll : Types.Model -> Roll -> ( Types.Model, Cmd Msg )
showRoll model roll =
    let
        board_ =
            Board.State.updateLands model.game.board [] <| Just Board.Types.Idle

        game =
            model.game

        game_ =
            { game | board = board_ }

        soundName =
            if List.sum roll.from.roll > List.sum roll.to.roll then
                "rollSuccess"
            else
                "rollDefeat"
    in
        ( { model | game = game_ }, playSound soundName )


clickLand : Types.Model -> Land.Land -> ( Types.Model, Cmd Types.Msg )
clickLand model land =
    case model.game.player of
        Nothing ->
            ( model, Cmd.none )

        Just player ->
            let
                ( move, cmd ) =
                    if not model.game.hasTurn then
                        ( model.game.board.move, Cmd.none )
                    else
                        case model.game.board.move of
                            Board.Types.Idle ->
                                if land.points > 1 && land.color == player.color then
                                    ( Board.Types.From land, Cmd.none )
                                else
                                    ( Board.Types.Idle, Cmd.none )

                            Board.Types.From from ->
                                if land == from then
                                    -- same land: deselect
                                    ( Board.Types.Idle, Cmd.none )
                                else if land.color == player.color then
                                    -- same color and...
                                    if land.points > 1 then
                                        -- could move: select
                                        ( Board.Types.From land, Cmd.none )
                                    else
                                        -- could not move: do nothing
                                        ( model.game.board.move, Cmd.none )
                                else if not <| Land.isBordering land from then
                                    -- not bordering: do nothing
                                    ( model.game.board.move, Cmd.none )
                                else
                                    -- is bordering, different land and color: attack
                                    let
                                        gameCmd =
                                            attack model.backend model.game.table from.emoji land.emoji
                                    in
                                        ( Board.Types.FromTo from land, Cmd.batch [ playSound "diceroll", gameCmd ] )

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


hoverLand : Types.Model -> Land.Land -> ( Types.Model, Cmd Types.Msg )
hoverLand model land =
    case model.game.player of
        Nothing ->
            ( model, Cmd.none )

        Just player ->
            let
                hovered =
                    if not model.game.hasTurn then
                        Nothing
                    else
                        case model.game.board.move of
                            Board.Types.Idle ->
                                if land.points > 1 && land.color == player.color then
                                    Just land
                                else
                                    Nothing

                            Board.Types.From from ->
                                if land == from then
                                    -- same land: deselect
                                    Just land
                                else if land.color == player.color then
                                    -- same color and...
                                    if land.points > 1 then
                                        -- could move: select
                                        Just land
                                    else
                                        -- could not move: do nothing
                                        Nothing
                                else if not <| Land.isBordering land from then
                                    -- not bordering: do nothing
                                    Nothing
                                else
                                    -- is bordering, different land and color: attack
                                    Just land

                            Board.Types.FromTo from to ->
                                Nothing

                game =
                    model.game

                board =
                    game.board
            in
                { model | game = { game | board = { board | hovered = hovered } } } ! []


updateTable : Types.Model -> Table -> Backend.Types.TableMessage -> ( Types.Model, Cmd Types.Msg )
updateTable model table msg =
    if table == model.game.table then
        case msg of
            Backend.Types.Error error ->
                updateChatLog model <| LogError error

            Backend.Types.Join user ->
                updateChatLog model <| LogJoin user

            Backend.Types.Leave user ->
                updateChatLog model <| LogLeave user

            Backend.Types.Chat user text ->
                let
                    color =
                        case user of
                            Nothing ->
                                Land.Black

                            Just name ->
                                model.game.players
                                    |> List.filter (\p -> p.name == name)
                                    |> List.head
                                    |> Maybe.map .color
                                    |> Maybe.withDefault Land.Black
                in
                    updateChatLog model <| LogChat user color text

            Backend.Types.Update status ->
                updateTableStatus model status

            Backend.Types.Roll roll ->
                let
                    ( firstModel, chatCmd ) =
                        updateChatLog model <|
                            Game.Types.LogRoll <|
                                Backend.toRollLog model roll

                    ( secondModel, gameCmd ) =
                        showRoll firstModel roll
                in
                    ( secondModel, Cmd.batch [ gameCmd, chatCmd ] )

            Backend.Types.Move move ->
                let
                    game =
                        model.game

                    board =
                        game.board

                    findLand =
                        (\emoji -> find (.emoji >> (==) emoji))

                    fromLand =
                        findLand move.from board.map.lands

                    toLand =
                        findLand move.to board.map.lands

                    newMove =
                        case fromLand of
                            Nothing ->
                                Nothing

                            Just fromLand ->
                                case toLand of
                                    Nothing ->
                                        Nothing

                                    Just toLand ->
                                        Just <| Board.Types.FromTo fromLand toLand
                in
                    case newMove of
                        Nothing ->
                            ( model, Cmd.none )

                        Just move ->
                            { model
                                | game =
                                    { game
                                        | board =
                                            { board
                                                | move = move
                                            }
                                    }
                            }
                                ! []

            Backend.Types.Elimination elimination ->
                updateChatLog model <|
                    Game.Types.LogElimination elimination.player.name elimination.player.color elimination.position elimination.score elimination.reason
    else
        model ! []


updateChatLog : Types.Model -> ChatLogEntry -> ( Types.Model, Cmd Types.Msg )
updateChatLog model entry =
    let
        game =
            model.game

        addToChatLog =
            { model | game = { game | chatLog = List.append game.chatLog [ entry ] } }

        addToGameLog =
            { model | game = { game | gameLog = List.append game.gameLog [ entry ] } }
    in
        case entry of
            LogJoin _ ->
                ( addToChatLog, scrollElement <| "chatLog-" ++ (toString model.game.table) )

            LogLeave _ ->
                ( addToChatLog, scrollElement <| "chatLog-" ++ (toString model.game.table) )

            LogChat _ _ _ ->
                ( addToChatLog, scrollElement <| "chatLog-" ++ (toString model.game.table) )

            _ ->
                ( addToGameLog, scrollElement <| "gameLog-" ++ (toString model.game.table) )


port scrollElement : String -> Cmd msg
