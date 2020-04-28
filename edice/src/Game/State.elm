module Game.State exposing (canSelect, changeTable, clickLand, gameCommand, init, isChat, setUser, tableMap, update, updateGameInfo, updateTable, updateTableStatus)

import Animation
import Backend
import Backend.MqttCommands exposing (attack, sendGameCommand)
import Backend.Types exposing (Topic(..))
import Board
import Board.State
import Board.Types exposing (BoardMove(..), Msg(..))
import Browser.Dom as Dom
import Game.Types exposing (..)
import Helpers exposing (consoleDebug, find, indexOf, pipeUpdates)
import Land exposing (LandUpdate)
import Maps exposing (load)
import Snackbar exposing (toastError, toastMessage)
import Tables exposing (Map(..), Table, isTournament)
import Task
import Time
import Types exposing (DialogStatus(..), Msg(..), SessionPreferences, User(..))


init : Maybe Table -> Maybe Map -> ( Game.Types.Model, Cmd Msg )
init table tableMap_ =
    let
        map : Result MapLoadError Land.Map
        map =
            case tableMap_ |> Result.fromMaybe "no current table-map" |> Result.andThen Maps.load of
                Ok landMap ->
                    Ok landMap

                Err err ->
                    case table of
                        Just t ->
                            case Maps.mapFromTable t of
                                Ok m ->
                                    Maps.load m |> Result.mapError MapLoadError

                                Err err2 ->
                                    if isTournament t then
                                        Err NoTableNoMapError

                                    else
                                        Err BadTableError

                        Nothing ->
                            Err NoTableNoMapError

        board =
            Board.init <| Result.withDefault Maps.emptyMap map
    in
    ( { table = table
      , board = board
      , boardOptions =
            { diceVisible = True
            , showEmojis = False
            }
      , hovered = Nothing
      , players = []
      , player = Nothing
      , status = Paused
      , gameStart = Nothing
      , playerSlots = 0
      , startSlots = 0
      , points = 0
      , turnIndex = -1
      , hasTurn = False
      , canMove = False
      , turnStart = -1
      , chatInput = ""
      , chatLog = []
      , gameLog =
            case table of
                Just aTable ->
                    [ LogBegin aTable ]

                Nothing ->
                    []
      , chatOverlay = Nothing
      , isPlayerOut = False
      , roundCount = 0
      , isReady = Nothing
      , flag = Nothing
      , params =
            { noFlagRounds = 0
            , botLess = True
            , startingCapitals = False
            , readySlots = Nothing
            , turnSeconds = Nothing
            , twitter = False
            , tournament = Nothing
            }
      , currentGame = Nothing
      , expandChat = False
      }
    , case map of
        Ok _ ->
            Cmd.none

        Err err ->
            case err of
                MapLoadError str ->
                    consoleDebug <| "Map loading error: " ++ str

                NoTableNoMapError ->
                    Cmd.none

                BadTableError ->
                    toastError "This table does not seem to exist" "BadTableError"
    )


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
            { model | game = newGame, dialog = Hide }

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

        ( game, cmd ) =
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


findPlayer : Model -> List Player -> Maybe Player
findPlayer game list =
    game.player
        |> Maybe.andThen (\p -> find (.id >> (==) p.id) list)


updateTableStatus : Types.Model -> Game.Types.TableStatus -> ( Types.Model, Cmd Msg )
updateTableStatus model status =
    let
        game =
            model.game

        player : Maybe Player
        player =
            findUserPlayer model.user status.players

        hasTurn =
            case player of
                Nothing ->
                    False

                Just turnPlayer ->
                    indexOf turnPlayer status.players == status.turnIndex

        isOut =
            case player of
                Nothing ->
                    False

                Just outPlayer ->
                    outPlayer.out

        oldBoard =
            model.game.board

        board_ =
            Board.State.updateLands oldBoard status.lands Nothing

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

        canMove =
            if not hasTurn then
                False

            else
                case player of
                    Nothing ->
                        False

                    Just turnPlayer ->
                        board_.map.lands
                            |> List.filter (\land -> land.color == turnPlayer.color && land.points > 1)
                            |> List.map (Board.canAttackFrom board_.map turnPlayer.color >> Result.toMaybe)
                            |> List.any ((==) Nothing >> not)

        game_ =
            { game
                | players = status.players
                , player = player
                , status = status.status
                , gameStart = gameStart
                , turnIndex = status.turnIndex
                , hasTurn = hasTurn
                , canMove = canMove
                , turnStart = status.turnStart
                , isPlayerOut = isOut
                , board = board_
                , roundCount = status.roundCount
                , currentGame = status.currentGame
            }

        model_ =
            { model | game = game_ }
    in
    ( model_
    , Cmd.batch
        [ if hasStarted then
            Cmd.batch <|
                playSound model.sessionPreferences "start"
                    :: (if not hasTurn then
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

        -- , case status.currentGame of
        -- Just id ->
        -- if status.currentGame /= game.currentGame then
        -- consoleDebug <| "gameId: " ++ String.fromInt id ++ ", " ++ String.fromInt (List.length game.chatLog)
        --
        -- else
        -- Cmd.none
        --
        -- Nothing ->
        -- Cmd.none
        ]
    )


updateTurn : Types.Model -> TurnInfo -> ( Types.Model, Cmd Msg )
updateTurn model { turnIndex, turnStart, roundCount, giveDice, players, lands } =
    let
        player : Maybe Player
        player =
            findUserPlayer model.user players

        newTurnPlayer : Maybe Player
        newTurnPlayer =
            List.drop turnIndex players |> List.head

        hasTurn =
            case player of
                Nothing ->
                    False

                Just turnPlayer ->
                    indexOf turnPlayer players == turnIndex

        hasGainedTurn =
            case player of
                Nothing ->
                    False

                Just _ ->
                    hasTurn && not model.game.hasTurn

        hasLostTurn =
            case player of
                Nothing ->
                    False

                Just _ ->
                    not hasTurn && model.game.hasTurn

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

        board =
            if List.length lands == 0 then
                game.board

            else
                Board.State.updateLands game.board lands Nothing

        canMove =
            if not hasTurn then
                False

            else
                case player of
                    Nothing ->
                        False

                    Just turnPlayer ->
                        board.map.lands
                            |> List.filter (\land -> land.color == turnPlayer.color && land.points > 1)
                            |> List.map (Board.canAttackFrom board.map turnPlayer.color >> Result.toMaybe)
                            |> List.any ((==) Nothing >> not)

        game =
            model.game

        game_ =
            { game
                | board = board
                , players = players
                , player = player
                , turnIndex = turnIndex
                , hasTurn = hasTurn
                , canMove = canMove
                , turnStart = turnStart
                , isPlayerOut = isOut
                , roundCount = roundCount
            }

        ( tmpModel, turnCmd ) =
            case newTurnPlayer of
                Just p ->
                    updateChatLog { model | game = game_ } <| LogTurn p.name p.color

                Nothing ->
                    ( { model | game = game_ }, Cmd.none )

        ( ( model_, receiveCmd ), givenDiceCount ) =
            case giveDice of
                Just ( p, count ) ->
                    ( updateChatLog tmpModel <| Game.Types.LogReceiveDice p count, count )

                Nothing ->
                    ( ( tmpModel, Cmd.none ), 0 )
    in
    ( model_
    , Cmd.batch <|
        [ if hasGainedTurn then
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
        , turnCmd
        , receiveCmd
        ]
            ++ (if givenDiceCount > 0 then
                    [ playSound model.sessionPreferences "giveDice" ]

                else
                    []
               )
    )


updatePlayerStatus : Types.Model -> Player -> ( Types.Model, Cmd Msg )
updatePlayerStatus model player =
    let
        game =
            model.game

        players =
            List.map
                (\p ->
                    if p.id == player.id then
                        player

                    else
                        p
                )
                game.players

        isUser =
            case game.player of
                Just p ->
                    player.id == p.id

                Nothing ->
                    False

        game_ =
            if isUser then
                let
                    isOut =
                        player.out

                    flag =
                        case player.flag of
                            Just _ ->
                                Nothing

                            Nothing ->
                                Nothing
                in
                { game
                    | players = players
                    , player =
                        if isUser then
                            Just player

                        else
                            game.player
                    , isPlayerOut = isOut
                    , flag = flag
                }

            else
                { game
                    | players = players
                    , player =
                        if isUser then
                            Just player

                        else
                            game.player
                }
    in
    ( { model | game = game_ }, Cmd.none )


updateGameInfo : ( Game.Types.Model, Cmd Msg ) -> List Game.Types.TableInfo -> ( Game.Types.Model, Cmd Msg )
updateGameInfo ( model, cmd ) tableList =
    case model.table of
        Nothing ->
            ( model, cmd )

        Just table ->
            let
                currentTableInfo =
                    tableList
                        |> List.filter (\t -> t.table == table)
                        |> List.head
            in
            case currentTableInfo of
                Just tableInfo ->
                    let
                        options =
                            model.boardOptions
                    in
                    ( { model
                        | playerSlots = tableInfo.playerSlots
                        , startSlots = tableInfo.startSlots
                        , points = tableInfo.points
                        , params = tableInfo.params
                        , boardOptions =
                            if tableInfo.params.twitter then
                                { options | showEmojis = True }

                            else
                                options
                      }
                    , cmd
                    )

                Nothing ->
                    ( model, cmd )


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

        players =
            roll.players

        player =
            findUserPlayer model.user players

        updates : List LandUpdate
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
                    , capital =
                        if success then
                            case Helpers.tupleCombine ( from.capital, to.capital ) of
                                Just ( fc, tc ) ->
                                    Just <| Land.Capital <| fc.count + tc.count + to.points

                                Nothing ->
                                    from.capital

                        else
                            from.capital
                    }
                        :: (if success then
                                [ { emoji = to.emoji
                                  , color = from.color
                                  , points = from.points - 1
                                  , capital = Nothing
                                  }
                                ]
                                    ++ (if success && from.capital == Nothing then
                                            case to.capital of
                                                Just tc ->
                                                    find (\l -> l.color == from.color && l.capital /= Nothing) game.board.map.lands
                                                        |> Maybe.andThen
                                                            (\capitalLand ->
                                                                capitalLand.capital |> Maybe.map (Tuple.pair capitalLand)
                                                            )
                                                        |> Maybe.map
                                                            (\( land, capital ) ->
                                                                [ { emoji = land.emoji
                                                                  , color = land.color
                                                                  , points = land.points
                                                                  , capital = Just <| Land.Capital <| capital.count + tc.count + to.points
                                                                  }
                                                                ]
                                                            )
                                                        |> Maybe.withDefault []

                                                Nothing ->
                                                    []
                                            -- TODO runtime error here - Result?

                                        else
                                            []
                                       )

                            else
                                []
                           )

                Nothing ->
                    []

        board_ =
            Board.State.updateLands model.game.board updates (Just Board.Types.Idle)

        game =
            model.game

        canMove =
            if not game.hasTurn then
                False

            else
                case player of
                    Nothing ->
                        False

                    Just p ->
                        board_.map.lands
                            |> List.filter (\land -> land.color == p.color && land.points > 1)
                            |> List.map (Board.canAttackFrom board_.map p.color >> Result.toMaybe)
                            |> List.any ((==) Nothing >> not)

        game_ =
            { game
                | board = board_
                , players = players
                , player = player
                , turnStart = roll.turnStart
                , canMove = canMove
            }

        soundName =
            if List.sum roll.from.roll > List.sum roll.to.roll then
                case player of
                    Just p ->
                        case fromLand of
                            Just land ->
                                if land.color == p.color then
                                    "rollSuccessPlayer"

                                else
                                    "rollSuccess"

                            Nothing ->
                                "rollSuccess"

                    Nothing ->
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
                        case Board.canMove model.game.board player.color emoji of
                            Ok newMove ->
                                case newMove of
                                    FromTo from to ->
                                        case model.game.table of
                                            Just table ->
                                                let
                                                    gameCmd =
                                                        attack model.backend table from.emoji to.emoji
                                                in
                                                ( newMove
                                                , Cmd.batch
                                                    [ gameCmd

                                                    -- , playSound model.sessionPreferences "diceroll"
                                                    ]
                                                )

                                            Nothing ->
                                                -- no table!
                                                ( model.game.board.move, consoleDebug "error: no table" )

                                    _ ->
                                        ( newMove, Cmd.none )

                            Err err ->
                                ( model.game.board.move, consoleDebug <| "click: " ++ err )

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


canSelect : Model -> Land.Emoji -> Bool
canSelect game emoji =
    case game.player of
        Nothing ->
            False

        Just player ->
            if not game.hasTurn then
                False

            else
                case Board.canMove game.board player.color emoji of
                    Ok _ ->
                        True

                    Err _ ->
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
                        updateChatLog
                            { model | game = updatePlayers model.game (List.filter (.id >> (/=) player.id) model.game.players) [] }
                        <|
                            LogLeave player

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

                            newMove =
                                case Land.findLand move.from board.map.lands of
                                    Nothing ->
                                        Nothing

                                    Just fromLand ->
                                        case Land.findLand move.to board.map.lands of
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
                                                        Board.Types.FromTo from _ ->
                                                            [ { color = from.color
                                                              , emoji = from.emoji
                                                              , points = from.points
                                                              , capital = from.capital
                                                              }
                                                            ]

                                                        _ ->
                                                            []
                                                    )
                                                    (Just move_)
                                        }
                                  }
                                , playSound model.sessionPreferences "kick"
                                )

                    Backend.Types.Eliminations eliminations players ->
                        List.foldl
                            (\elimination ( model_, cmd ) ->
                                let
                                    ( m, c ) =
                                        updateChatLog model_ <|
                                            Game.Types.LogElimination elimination.player.name elimination.player.color elimination.position elimination.score elimination.reason
                                in
                                ( m, Cmd.batch [ cmd, c ] )
                            )
                            ( { model | game = updatePlayers model.game players (List.map (.player >> .color) eliminations) }, Cmd.none )
                            eliminations

                    Backend.Types.Turn info ->
                        updateTurn model info

                    Backend.Types.PlayerStatus player ->
                        updatePlayerStatus model player

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
    if model.fullscreen then
        let
            game =
                model.game

            game_ =
                case entry of
                    LogChat _ _ _ ->
                        { game | chatOverlay = Just ( model.time, entry ) }

                    _ ->
                        game
        in
        ( { model | game = game_ }, Cmd.none )

    else
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
                { model
                    | game =
                        { game
                            | chatLog = List.append game.chatLog [ entry ]
                        }
                }

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

        ToggleDiceVisible visible ->
            let
                options =
                    model.game.boardOptions
            in
            ( { model
                | game = { game | boardOptions = { options | diceVisible = visible } }
              }
            , Cmd.none
            )


setUser : Model -> Types.LoggedUser -> Model
setUser model user =
    { model | player = findLoggedUserPlayer user model.players }


updatePlayers : Model -> List Player -> List Land.Color -> Model
updatePlayers model newPlayers removedColor =
    let
        player : Maybe Player
        player =
            findPlayer model newPlayers

        model_ =
            if List.length removedColor > 0 then
                { model
                    | players = newPlayers
                    , player =
                        case player of
                            Just p ->
                                Just p

                            Nothing ->
                                model.player
                    , board =
                        if List.length newPlayers > 1 then
                            List.foldl
                                (\color board ->
                                    Board.State.removeColor board color
                                )
                                model.board
                                removedColor

                        else
                            model.board
                }

            else
                { model | players = newPlayers }
    in
    case model.player of
        Just p ->
            if not <| List.any (.id >> (==) p.id) newPlayers then
                { model_
                    | isPlayerOut = False
                    , player = Nothing
                    , hasTurn = False
                    , isReady = Nothing
                    , flag = Nothing
                }

            else
                model_

        Nothing ->
            model_


playSound : SessionPreferences -> String -> Cmd Msg
playSound preferences sound =
    if preferences.muted then
        Cmd.none

    else
        Helpers.playSound sound
