module Game.State exposing (canHover, changeTable, clickLand, gameCommand, init, setUser, tableMap, update, updateGameInfo, updateTable, updateTableStatus)

import Backend
import Backend.MqttCommands exposing (attack, sendGameCommand)
import Backend.Types exposing (Topic(..))
import Board
import Board.State
import Board.Types exposing (Msg(..))
import Browser.Dom as Dom
import Game.Types exposing (..)
import Helpers exposing (consoleDebug, find, indexOf, pipeUpdates)
import Land
import Maps exposing (load)
import Snackbar exposing (toastMessage)
import Tables exposing (Map, Table)
import Task
import Types exposing (Msg(..), SessionPreferences, User(..))


init : Maybe Table -> Maybe Map -> Game.Types.Model
init table tableMap_ =
    let
        map =
            Maybe.map Maps.load tableMap_
                |> Maybe.withDefault
                    (Maybe.andThen mapFromTable table
                        |> Maybe.map Maps.load
                        |> Maybe.withDefault Maps.emptyMap
                    )

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
    , startSlots = 0
    , points = 0
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
    , playerPosition = 0
    , roundCount = 0
    , canFlag = False
    , isReady = Nothing
    , flag = Nothing
    , params =
        { noFlagRounds = 0
        , botLess = True
        }
    , currentGame = Nothing
    }


gameCommand : Types.Model -> PlayerAction -> ( Types.Model, Cmd Msg )
gameCommand model playerAction =
    ( case playerAction of
        Join ->
            let
                game =
                    model.game

                newGame =
                    { game | isReady = Nothing }
            in
            { model | game = newGame }

        ToggleReady ready ->
            let
                game =
                    model.game

                newGame =
                    { game | isReady = Just ready }
            in
            { model | game = newGame }

        Flag flag ->
            let
                game =
                    model.game

                newGame =
                    { game | flag = Just flag }
            in
            { model | game = newGame }

        _ ->
            model
    , Cmd.batch <|
        sendGameCommand model.backend model.game.table playerAction
            :: (case playerAction of
                    Join ->
                        [ playSound model.sessionPreferences "kick" ]

                    _ ->
                        []
               )
    )


changeTable : Types.Model -> Table -> ( Types.Model, Cmd Types.Msg )
changeTable model table =
    let
        map =
            tableMap table model.tableList

        game =
            updateGameInfo (init (Just table) map) model.tableList

        model_ =
            { model | game = game }
    in
    ( model_, Cmd.none )
        |> pipeUpdates Backend.subscribeGameTable table


tableMap : Table -> List Game.Types.TableInfo -> Maybe Map
tableMap table tableList =
    Maybe.map .mapName
        (List.filter (\t -> t.table == table) tableList
            |> List.head
        )


mapFromTable : Table -> Maybe Map
mapFromTable =
    Tables.decodeMap


findUserPlayer : Types.User -> List Player -> Maybe Player
findUserPlayer user players =
    case user of
        Types.Anonymous ->
            Nothing

        Types.Logged logged ->
            findLoggedUserPlayer logged players


findLoggedUserPlayer : Types.LoggedUser -> List Player -> Maybe Player
findLoggedUserPlayer logged players =
    players
        |> List.filter (.id >> (==) logged.id)
        |> List.head


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
            -- what was this hack?
            -- if model.game.board.map == Maps.emptyMap then
            -- Board.init <| Maps.load status.mapName
            --
            -- else
            model.game.board

        board_ =
            Board.State.updateLands oldBoard model.time status.lands move AnimationDone

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
                    (status.roundCount > game.params.noFlagRounds)
                        && canFlagPlayer.gameStats.position
                        > 1
                        && (case canFlagPlayer.flag of
                                Just f ->
                                    f < canFlagPlayer.gameStats.position

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
                , playerPosition = Maybe.withDefault 0 <| Maybe.map (.gameStats >> .position) player
                , currentGame = status.currentGame
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
                playSound model.sessionPreferences "start"
                    :: (if hasTurn then
                            [ Helpers.notification <| Just "game-start" ]

                        else
                            []
                       )

          else
            Cmd.none
        , if hasFinished then
            Cmd.batch
                [ playSound model.sessionPreferences "finish"
                , Helpers.notification Nothing
                ]

          else
            Cmd.none
        , if hasGainedTurn then
            Cmd.batch
                [ playSound model.sessionPreferences "turn"
                , Helpers.notification <| Just "game-turn"
                ]

          else
            Cmd.none
        , if hasLostTurn then
            Helpers.notification Nothing

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
                    { model
                        | playerSlots = tableInfo.playerSlots
                        , startSlots = tableInfo.startSlots
                        , points = tableInfo.points
                        , params = tableInfo.params
                    }

                Nothing ->
                    model


showRoll : Types.Model -> Roll -> ( Types.Model, Cmd Msg )
showRoll model roll =
    let
        fromLand =
            Land.findLand roll.from.emoji model.game.board.map.lands

        toLand =
            Land.findLand roll.to.emoji model.game.board.map.lands

        tuple : Maybe ( Land.Land, Land.Land )
        tuple =
            Maybe.map2 Tuple.pair fromLand toLand

        updates : List Board.Types.LandUpdate
        updates =
            case tuple of
                Just ( from, to ) ->
                    let
                        success =
                            List.sum roll.from.roll > List.sum roll.to.roll
                    in
                    { emoji = from.emoji
                    , color = from.color
                    , points = 1
                    }
                        :: (if success then
                                [ { emoji = to.emoji
                                  , color = from.color
                                  , points = from.points - 1
                                  }
                                ]

                            else
                                []
                           )

                Nothing ->
                    []

        board_ =
            Board.State.updateLands model.game.board model.time updates (Just Board.Types.Idle) AnimationDone

        game =
            model.game

        game_ =
            { game | board = board_, turnStart = roll.turnStart, players = roll.players }

        soundName =
            if List.sum roll.from.roll > List.sum roll.to.roll then
                "rollSuccess"

            else
                "rollDefeat"
    in
    ( { model | game = game_ }, playSound model.sessionPreferences soundName )


clickLand : Types.Model -> Land.Emoji -> ( Types.Model, Cmd Types.Msg )
clickLand model emoji =
    case model.game.player of
        Nothing ->
            ( model, consoleDebug "not logged in" )

        Just player ->
            let
                ( move, cmd ) =
                    if not model.game.hasTurn then
                        ( model.game.board.move, consoleDebug "not hasTurn" )

                    else
                        case find (.emoji >> (==) emoji) model.game.board.map.lands of
                            Just land ->
                                case model.game.board.move of
                                    Board.Types.Idle ->
                                        if land.points > 1 && land.color == player.color then
                                            ( Board.Types.From land, Cmd.none )

                                        else
                                            ( Board.Types.Idle, consoleDebug "cannot select foreign land" )

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
                                                ( model.game.board.move, consoleDebug "cannot select" )

                                        else if not <| Land.isBordering model.game.board.map land from then
                                            -- not bordering: do nothing
                                            ( model.game.board.move, consoleDebug "cannot attack far land" )

                                        else
                                            -- is bordering, different land and color: attack
                                            case model.game.table of
                                                Just table ->
                                                    let
                                                        gameCmd =
                                                            attack model.backend table from.emoji land.emoji
                                                    in
                                                    ( Board.Types.FromTo from land, Cmd.batch [ playSound model.sessionPreferences "diceroll", gameCmd ] )

                                                Nothing ->
                                                    -- no table!
                                                    ( model.game.board.move, consoleDebug "error: no table" )

                                    Board.Types.FromTo _ _ ->
                                        ( model.game.board.move, consoleDebug "ongoing attack" )

                            Nothing ->
                                ( model.game.board.move, consoleDebug <| "error: ClickLand not found: " ++ emoji )

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


canHover : Model -> Land.Emoji -> Bool
canHover game emoji =
    case game.player of
        Nothing ->
            False

        Just player ->
            if not game.hasTurn then
                False

            else
                case Land.findLand emoji game.board.map.lands of
                    Just land ->
                        case game.board.move of
                            Board.Types.Idle ->
                                if land.points > 1 && land.color == player.color then
                                    True

                                else
                                    False

                            Board.Types.From from ->
                                if land == from then
                                    -- same land: deselect
                                    True

                                else if land.color == player.color then
                                    -- same color and...
                                    if land.points > 1 then
                                        -- could move: select
                                        True

                                    else
                                        -- could not move: do nothing
                                        False

                                else if not <| Land.isBordering game.board.map land from then
                                    -- not bordering: do nothing
                                    False

                                else
                                    -- is bordering, different land and color: attack
                                    True

                            Board.Types.FromTo _ _ ->
                                False

                    Nothing ->
                        False


updateTable : Types.Model -> Table -> Backend.Types.TableMessage -> ( Types.Model, Cmd Types.Msg )
updateTable model table msg =
    case model.game.table of
        Just gameTable ->
            if table == gameTable then
                case msg of
                    Backend.Types.Error error ->
                        updateChatLog model <| LogError error

                    Backend.Types.Join player ->
                        updateChatLog model <| LogJoin player

                    Backend.Types.Leave player ->
                        updateChatLog model <| LogLeave player

                    Backend.Types.Enter user ->
                        updateChatLog model <| LogEnter user

                    Backend.Types.Exit user ->
                        updateChatLog model <| LogExit user

                    Backend.Types.Chat user text ->
                        let
                            color =
                                case user of
                                    Nothing ->
                                        Land.Black

                                    Just name ->
                                        userColor model.game.players name
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
                                                    model.time
                                                    (case move_ of
                                                        Board.Types.FromTo from _ ->
                                                            [ { color = from.color
                                                              , emoji = from.emoji
                                                              , points = from.points
                                                              }
                                                            ]

                                                        _ ->
                                                            []
                                                    )
                                                    (Just move_)
                                                    AnimationDone

                                            --{ board
                                            --| move = Debug.log "bck move" move_
                                            --}
                                        }
                                  }
                                , playSound model.sessionPreferences "kick"
                                )

                    Backend.Types.Elimination elimination ->
                        updateChatLog
                            { model | game = removePlayer model.game elimination.player }
                        <|
                            Game.Types.LogElimination elimination.player.name elimination.player.color elimination.position elimination.score elimination.reason

                    Backend.Types.ReceiveDice player count ->
                        updateChatLog model <|
                            Game.Types.LogReceiveDice player count

            else
                ( model
                , Cmd.none
                )

        Nothing ->
            ( model, Cmd.none )


isChat : ChatLogEntry -> Bool
isChat entry =
    case entry of
        LogEnter _ ->
            True

        LogExit _ ->
            True

        LogChat _ _ _ ->
            True

        _ ->
            False


updateChatLog : Types.Model -> ChatLogEntry -> ( Types.Model, Cmd Types.Msg )
updateChatLog model entry =
    case model.game.table of
        Nothing ->
            ( model, Cmd.none )

        Just table ->
            ( model
            , updateChatCmd table entry <|
                if isChat entry then
                    "chatLog"

                else
                    "gameLog"
            )


updateChatCmd : Table -> ChatLogEntry -> String -> Cmd Types.Msg
updateChatCmd table entry idPrefix =
    Dom.getViewportOf (idPrefix ++ "-" ++ table)
        |> Task.attempt (\info -> GameMsg <| Game.Types.ScrollChat (idPrefix ++ "-" ++ table) entry info)


update : Types.Model -> Game.Types.Model -> Game.Types.Msg -> ( Types.Model, Cmd Types.Msg )
update model game msg =
    case msg of
        ScrollChat id entry res ->
            ( if isChat entry then
                { model | game = { game | chatLog = List.append game.chatLog [ entry ] } }

              else
                { model | game = { game | gameLog = List.append game.gameLog [ entry ] } }
            , Cmd.batch
                [ case res of
                    Err _ ->
                        consoleDebug "cannot scroll chat"

                    Ok info ->
                        if info.viewport.y + info.viewport.height + 10 >= info.scene.height then
                            Dom.setViewportOf id 0 info.scene.height
                                |> Task.attempt
                                    (\_ -> Nop)

                        else
                            Cmd.none
                , case entry of
                    LogReceiveDice player count ->
                        case game.player of
                            Just me ->
                                if player.id == me.id && count < player.gameStats.totalLands then
                                    toastMessage
                                        ("You missed "
                                            ++ (String.fromInt <| player.gameStats.totalLands - count)
                                            ++ " dice because you have disconnected lands!"
                                        )
                                    <|
                                        Just 10000

                                else
                                    Cmd.none

                            Nothing ->
                                Cmd.none

                    _ ->
                        Cmd.none
                ]
            )


setUser : Model -> Types.LoggedUser -> Model
setUser model user =
    { model | player = findLoggedUserPlayer user model.players }


removePlayer : Model -> Player -> Model
removePlayer model player =
    { model | players = List.filter (.id >> (==) player.id >> not) model.players }


playSound : SessionPreferences -> String -> Cmd Msg
playSound preferences sound =
    if preferences.muted then
        Cmd.none

    else
        Helpers.playSound sound
