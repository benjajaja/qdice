port module Game.State exposing (changeTable, clickLand, findUserPlayer, hoverLand, init, scrollElement, showRoll, tableMap, updateGameInfo, updateTable, updateTableStatus)

import Backend
import Backend.MqttCommands exposing (attack, gameCommand)
import Backend.Types exposing (Topic(..))
import Board
import Board.State
import Board.Types
import Browser.Dom exposing (..)
import Game.Types exposing (..)
import Helpers exposing (find, indexOf, pipeUpdates, playSound)
import Land exposing (Color)
import Maps exposing (load)
import Tables exposing (Map, Table)
import Task
import Types exposing (Model, Msg(..), User(..))


init : Maybe Table -> Maybe Map -> Game.Types.Model
init table tableMap_ =
    let
        map =
            Maybe.map Maps.load tableMap_
                |> Maybe.withDefault Land.emptyMap

        board =
            Board.init map

        players =
            []
    in
        { table = table
        , board = board
        , players = players
        , player = Nothing
        , status = Paused
        , gameStart = Nothing
        , playerSlots = 0
        , turnIndex = -1
        , hasTurn = False
        , turnStart = -1
        , chatInput = ""
        , chatLog = []
        , gameLog =
            case table of
                Just aTable ->
                    [ LogBegin aTable ]

                Nothing ->
                    []
        , isPlayerOut = False
        , roundCount = 0
        , canFlag = False
        }


changeTable : Types.Model -> Table -> ( Types.Model, Cmd Types.Msg )
changeTable model table =
    let
        previousTable =
            model.game.table

        map =
            tableMap table model.tableList

        game =
            init (Just table) map

        model_ =
            { model | game = game }
    in
        ( model_, Cmd.none )
            |> pipeUpdates Backend.subscribeGameTable table


tableMap : Table -> List Game.Types.TableInfo -> Maybe Map
tableMap table tableList =
    case
        List.filter (\t -> t.table == table) tableList
            |> List.head
    of
        Just tableInfo ->
            Just tableInfo.mapName

        Nothing ->
            Nothing


findUserPlayer : Types.User -> List Player -> Maybe Player
findUserPlayer user players =
    case user of
        Types.Anonymous ->
            Nothing

        Types.Logged user_ ->
            List.head <| List.filter (\p -> p.id == user_.id) players


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

                Just turnPlayer ->
                    indexOf turnPlayer status.players == status.turnIndex

        hasGainedTurn =
            case player of
                Nothing ->
                    False

                Just _ ->
                    hasTurn && not game.hasTurn

        hasLostTurn =
            case player of
                Nothing ->
                    False

                Just _ ->
                    not hasTurn && game.hasTurn

        isOut =
            case player of
                Nothing ->
                    False

                Just outPlayer ->
                    outPlayer.out

        move =
            if hasLostTurn then
                Just Board.Types.Idle
            else
                Nothing

        oldBoard =
            if model.game.board.map == Land.emptyMap then
                Board.init <| Maps.load status.mapName
            else
                model.game.board

        board_ =
            Board.State.updateLands oldBoard status.lands move

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

                Just canFlagPlayer ->
                    status.canFlag
                        && canFlagPlayer.gameStats.position
                        > 1
                        && (case canFlagPlayer.flag of
                                Just f ->
                                    False

                                Nothing ->
                                    True
                           )

        game_ =
            { game
                | players = status.players
                , player = player
                , status = status.status
                , gameStart = gameStart
                , turnIndex = status.turnIndex
                , hasTurn = hasTurn
                , turnStart = status.turnStart
                , isPlayerOut = isOut
                , board = board_
                , roundCount = status.roundCount
                , canFlag = canFlag
            }

        ( model_, turnChangeCmd ) =
            { model | game = game_ }
                |> (\m ->
                        case hasChangedTurn of
                            Just changedTurnPlayer ->
                                updateChatLog m <| LogTurn changedTurnPlayer.name changedTurnPlayer.color

                            Nothing ->
                                ( m, Cmd.none )
                   )
    in
        ( model_
        , Cmd.batch
            [ if hasStarted then
                Cmd.batch <|
                    Helpers.playSound "start"
                        :: (if hasTurn then
                                [ Helpers.setFavicon "alert" ]
                            else
                                []
                           )
              else
                Cmd.none
            , if hasFinished then
                Cmd.batch
                    [ Helpers.playSound "finish"
                    , Helpers.setFavicon ""
                    ]
              else
                Cmd.none
            , if hasGainedTurn then
                Cmd.batch
                    [ Helpers.playSound "turn"
                    , Helpers.setFavicon "alert"
                    ]
              else
                Cmd.none
            , if hasLostTurn then
                Helpers.setFavicon ""
              else
                Cmd.none
            , turnChangeCmd
            ]
        )


updateGameInfo : Game.Types.Model -> List Game.Types.TableInfo -> Game.Types.Model
updateGameInfo model tableList =
    case model.table of
        Nothing ->
            model

        Just table ->
            let
                currentTableInfo =
                    tableList
                        |> List.filter (\t -> t.table == table)
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
                                    case model.game.table of
                                        Just table ->
                                            let
                                                gameCmd =
                                                    attack model.backend table from.emoji land.emoji
                                            in
                                                ( Board.Types.FromTo from land, Cmd.batch [ playSound "diceroll", gameCmd ] )

                                        Nothing ->
                                            -- no table!
                                            ( model.game.board.move, Cmd.none )

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
                ( { model | game = game_ }
                , cmd
                )


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
                ( { model | game = { game | board = { board | hovered = hovered } } }
                , Cmd.none
                )


updateTable : Types.Model -> Table -> Backend.Types.TableMessage -> ( Types.Model, Cmd Types.Msg )
updateTable model table msg =
    case model.game.table of
        Just gameTable ->
            if table == gameTable then
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
                                \emoji -> find (.emoji >> (==) emoji)

                            newMove =
                                case findLand move.from board.map.lands of
                                    Nothing ->
                                        Nothing

                                    Just fromLand ->
                                        case findLand move.to board.map.lands of
                                            Nothing ->
                                                Nothing

                                            Just toLand ->
                                                Just <| Board.Types.FromTo fromLand toLand
                        in
                            case newMove of
                                Nothing ->
                                    ( model, Cmd.none )

                                Just move_ ->
                                    ( { model
                                        | game =
                                            { game
                                                | board =
                                                    Board.State.updateLands
                                                        board
                                                        (case move_ of
                                                            Board.Types.FromTo from to ->
                                                                [ { color = from.color
                                                                  , emoji = from.emoji
                                                                  , points = from.points
                                                                  }
                                                                ]

                                                            _ ->
                                                                []
                                                        )
                                                    <|
                                                        Just move_
                                                    --{ board
                                                    --| move = Debug.log "bck move" move_
                                                    --}
                                            }
                                      }
                                    , Cmd.none
                                    )

                    Backend.Types.Elimination elimination ->
                        updateChatLog model <|
                            Game.Types.LogElimination elimination.player.name elimination.player.color elimination.position elimination.score elimination.reason
            else
                ( model
                , Cmd.none
                )

        Nothing ->
            ( model, Cmd.none )


updateChatLog : Types.Model -> ChatLogEntry -> ( Types.Model, Cmd Types.Msg )
updateChatLog model entry =
    case model.game.table of
        Nothing ->
            ( model, Cmd.none )

        Just table ->
            case entry of
                LogJoin _ ->
                    updateChat model model.game table entry

                LogLeave _ ->
                    updateChat model model.game table entry

                LogChat _ _ _ ->
                    updateChat model model.game table entry

                _ ->
                    updateLog model model.game table entry


updateChat : Types.Model -> Game.Types.Model -> Table -> ChatLogEntry -> ( Types.Model, Cmd Types.Msg )
updateChat model game table entry =
    ( { model | game = { game | chatLog = List.append game.chatLog [ entry ] } }, scrollElement <| "chatLog-" ++ table )


updateLog : Types.Model -> Game.Types.Model -> Table -> ChatLogEntry -> ( Types.Model, Cmd Types.Msg )
updateLog model game table entry =
    ( { model | game = { game | gameLog = List.append game.gameLog [ entry ] } }, scrollElement <| "gameLog-" ++ table )


port scrollElement : String -> Cmd msg
