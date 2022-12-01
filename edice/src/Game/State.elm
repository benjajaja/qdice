module Game.State exposing (canSelect, changeTable, clickLand, gameCommand, init, isChat, setUser, tableMap, update, updateGameInfo, updateTable, updateTableStatus)

import Backend
import Backend.HttpCommands
import Backend.MqttCommands exposing (attack, sendGameCommand)
import Backend.Types exposing (Topic(..))
import Board
import Board.State
import Board.Types exposing (BoardMove(..), Msg(..))
import Browser.Dom as Dom
import Dict
import Game.Types exposing (..)
import Helpers exposing (consoleDebug, find, indexOf, pipeUpdates)
import Land exposing (DiceSkin(..), LandUpdate, Map, filterMapLands)
import Maps
import Snackbar exposing (toastError, toastMessage)
import Tables exposing (MapName(..), Table, isTournament)
import Task
import Types exposing (DialogStatus(..), Msg(..), SessionPreferences, User(..))
import Board.Types exposing (DiceVisible(..))


init : Maybe Table -> Maybe MapName -> Maybe Int -> ( Game.Types.Model, Cmd Msg )
init table tableMap_ height =
    let
        map : Result MapLoadError Map
        map =
            case tableMap_ |> Result.fromMaybe "no current table-map" |> Result.andThen Maps.load of
                Ok landMap ->
                    Ok landMap

                Err _ ->
                    case table of
                        Just t ->
                            case Maps.mapFromTable t of
                                Ok m ->
                                    Maps.load m |> Result.mapError MapLoadError

                                Err _ ->
                                    if isTournament t then
                                        Err <| NoTableNoMapError t

                                    else
                                        Err <| BadTableError t

                        Nothing ->
                            Err <| NoTableNoMapError "(Nothing)"

        board =
            Board.State.init
               { diceVisible = Visible
                  , showEmojis = False
                  , height = height
                  }
               <| Result.withDefault Maps.emptyMap map
    in
    ( { table = table
      , board = board
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
            , tournament = Nothing
            }
      , currentGame = Nothing
      , expandChat = False
      , lastRoll =
            Nothing

      -- Just <|
      -- RollUI ( Land.Red, [ 0, 0, 0, 0, 0 ] )
      -- ( Land.Yellow, [ 0, 1, 1, 1, 5, 4, 5, 3 ] )
      -- True
      -- (Time.millisToPosix 100000000000000)
      , chartHinted = Nothing
      }
    , case map of
        Ok _ ->
            Cmd.none

        Err err ->
            case err of
                MapLoadError str ->
                    consoleDebug <| "Map loading error: " ++ str

                NoTableNoMapError tableName ->
                    toastError "This table/map does not seem to exist" ("NoTableNoMapError: " ++ tableName)

                BadTableError tableName ->
                    toastError "This table does not seem to exist" ("BadTableError: " ++ tableName)
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
            updateGameInfo (init (Just table) map model.fullscreen) model.tableList

        model_ =
            { model | game = game }
    in
    ( model_, cmd )
        |> pipeUpdates Backend.subscribeGameTable ( table, model.game.table )
        |> pipeUpdates fetchTableTop table


tableMap : Table -> List Game.Types.TableInfo -> Maybe MapName
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


{-| usually out of game
-}
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
            player |> Maybe.andThen .out |> Maybe.map (always True) |> Maybe.withDefault False

        oldBoard =
            model.game.board

        hasStarted =
            game.status /= Playing && status.status == Playing

        board_ : Board.Types.Model
        board_ =
            (if oldBoard.map.name /= status.mapName then
                Maps.load status.mapName
                    |> Result.map (Board.State.init oldBoard.boardOptions)
                    |> Result.toMaybe
                    |> Maybe.withDefault oldBoard

             else
                oldBoard
            )
                |> (\b -> Board.State.updateLands b status.lands Nothing status.players)
                |> (if hasStarted then
                        \b -> { b | avatarUrls = Just <| List.map (\p -> ( p.color, p.picture )) status.players }

                    else
                        identity
                   )

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
                        filterMapLands
                            board_.map.lands
                            (\land ->
                                if land.color == turnPlayer.color && land.points > 1 then
                                    Board.canAttackFrom board_.map turnPlayer.color land
                                        |> Result.toMaybe

                                else
                                    Nothing
                            )
                            |> List.length
                            |> (>) 0

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
            player |> Maybe.andThen .out |> Maybe.map (always True) |> Maybe.withDefault False

        move =
            if hasLostTurn then
                Just Board.Types.Idle

            else
                Nothing

        board =
            if List.length lands == 0 then
                game.board

            else
                Board.State.updateLands game.board lands move players

        canMove =
            if not hasTurn then
                False

            else
                case player of
                    Nothing ->
                        False

                    Just turnPlayer ->
                        filterMapLands
                            board.map.lands
                            (\land ->
                                if land.color == turnPlayer.color && land.points > 1 then
                                    Board.canAttackFrom board.map turnPlayer.color land
                                        |> Result.toMaybe

                                else
                                    Nothing
                            )
                            |> List.length
                            |> (>) 0

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
                    updateChatLog { model | game = game_ } <| [ LogTurn p.name p.color ]

                Nothing ->
                    ( { model | game = game_ }, Cmd.none )

        ( ( model_, receiveCmd ), givenDiceCount ) =
            case giveDice of
                Just ( p, count ) ->
                    ( updateChatLog tmpModel <| [ LogReceiveDice p count ], count )

                Nothing ->
                    ( ( tmpModel, Cmd.none ), 0 )
    in
    ( model_
    , Cmd.batch <|
        [ if
            hasGainedTurn
                && (case player of
                        Just p ->
                            p.out == Nothing

                        Nothing ->
                            False
                   )
          then
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
                        player.out |> Maybe.map (always True) |> Maybe.withDefault False
                in
                { game
                    | players = players
                    , player =
                        if isUser then
                            Just player

                        else
                            game.player
                    , isPlayerOut = isOut
                    , flag = Nothing -- is this right?
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
                    ( { model
                        | playerSlots = tableInfo.playerSlots
                        , startSlots = tableInfo.startSlots
                        , points = tableInfo.points
                        , params = tableInfo.params
                      }
                    , cmd
                    )

                Nothing ->
                    ( model, cmd )


showMove : Types.Model -> Move -> Types.Model
showMove model move =
    let
        game =
            model.game

        board =
            game.board

        newMove =
            Maybe.map2
                Board.Types.FromTo
                (Land.findLand move.from board.map.lands)
                (Land.findLand move.to board.map.lands)
    in
    case newMove of
        Nothing ->
            model

        Just move_ ->
            { model
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
                                model.game.players
                        , lastRoll =
                            case move_ of
                                Board.Types.FromTo from to ->
                                    Just
                                        { from =
                                            ( from.color
                                            , List.range 1 from.points
                                                |> List.map (always 0)
                                                |> Helpers.timeRandomDice model.time
                                            )
                                        , to =
                                            ( to.color
                                            , List.range 1 to.points
                                                |> List.map (always 0)
                                                |> Helpers.timeRandomDice model.time
                                            )
                                        , rolling =
                                            case game.board.boardOptions.diceVisible of
                                              Numbers -> Nothing
                                              _ -> Just model.time
                                        , timestamp = model.time
                                        }

                                _ ->
                                    Nothing
                    }
            }


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
                                { emoji = to.emoji
                                , color = from.color
                                , points = from.points - 1
                                , capital = Nothing
                                }
                                    :: (if success && from.capital == Nothing then
                                            case to.capital of
                                                Just tc ->
                                                    game.board.map.lands
                                                        |> Dict.values
                                                        |> find (\l -> l.color == from.color && l.capital /= Nothing)
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
            Board.State.updateLands model.game.board updates (Just Board.Types.Idle) players

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
                        filterMapLands
                            board_.map.lands
                            (\land ->
                                if land.color == p.color && land.points > 1 then
                                    Board.canAttackFrom board_.map p.color land
                                        |> Result.toMaybe

                                else
                                    Nothing
                            )
                            |> List.length
                            |> (>) 0

        lastRoll : Maybe RollUI
        lastRoll =
            Helpers.tupleCombine ( fromLand, toLand )
                |> Maybe.map
                    (\( from, to ) ->
                        { from = ( from.color, roll.from.roll )
                        , to = ( to.color, roll.to.roll )
                        , rolling = Nothing
                        , timestamp = model.time
                        }
                    )

        game_ =
            { game
                | board = board_
                , players = players
                , player = player
                , turnStart = roll.turnStart
                , canMove = canMove
                , lastRoll = lastRoll
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
                        updateChatLog model <| [ LogError error ]

                    Backend.Types.Join player ->
                        updateChatLog model <| [ LogJoin player ]

                    Backend.Types.Leave player ->
                        updateChatLog
                            { model | game = updatePlayers model.game (List.filter (.id >> (/=) player.id) model.game.players) [] }
                        <|
                            [ LogLeave player ]

                    Backend.Types.Takeover player replaced ->
                        let
                            ( model_, cmd ) =
                                updateChatLog
                                    { model
                                        | game =
                                            updatePlayers model.game
                                                (List.map
                                                    (\p ->
                                                        if p.id == replaced.id then
                                                            player

                                                        else
                                                            p
                                                    )
                                                    model.game.players
                                                )
                                                []
                                    }
                                <|
                                    [ LogTakeover player replaced ]
                        in
                        ( model_
                        , Cmd.batch
                            [ cmd
                            , toastMessage (player.name ++ " has taken over " ++ replaced.name) <| Just 10000
                            ]
                        )

                    Backend.Types.Enter user ->
                        updateChatLog model <| [ LogEnter user ]

                    Backend.Types.Exit user ->
                        updateChatLog model <| [ LogExit user ]

                    Backend.Types.Chat lines ->
                        updateChatLog model <|
                            List.map
                                (Helpers.tupleApply LogChat)
                                lines

                    Backend.Types.Update status ->
                        updateTableStatus model status

                    Backend.Types.Roll roll ->
                        let
                            ( firstModel, chatCmd ) =
                                updateChatLog model <|
                                    [ Game.Types.LogRoll <|
                                        Backend.toRollLog model roll
                                    ]

                            ( secondModel, gameCmd ) =
                                showRoll firstModel roll
                        in
                        ( secondModel, Cmd.batch [ gameCmd, chatCmd ] )

                    Backend.Types.Move move ->
                        ( showMove model move
                        , playSound model.sessionPreferences "kick"
                        )

                    Backend.Types.Eliminations eliminations players ->
                        let
                            ( model_, cmds ) =
                                List.foldl
                                    (\elimination ( next, cmd ) ->
                                        let
                                            ( m, c ) =
                                                updateChatLog next <|
                                                    [ Game.Types.LogElimination elimination.player.name elimination.player.color elimination.position elimination.score elimination.reason ]
                                        in
                                        ( m, Cmd.batch [ cmd, c ] )
                                    )
                                    ( { model | game = updatePlayers model.game players (List.map (.player >> .color) eliminations) }, Cmd.none )
                                    eliminations
                        in
                        if List.any (\e -> e.position == 1) eliminations then
                            let
                                ( m, c ) =
                                    case model.game.currentGame of
                                        Just id ->
                                            case model.game.table of
                                                Just t ->
                                                    updateChatLog model_ <| [ Game.Types.LogEndGame t id ]

                                                Nothing ->
                                                    ( model, Cmd.none )

                                        Nothing ->
                                            ( model, Cmd.none )
                            in
                            ( m, Cmd.batch [ c, cmds ] )

                        else
                            ( model_, cmds )

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

        LogChat _ _ ->
            True

        _ ->
            False


updateChatLog : Types.Model -> List ChatLogEntry -> ( Types.Model, Cmd Types.Msg )
updateChatLog model entries =
    if model.fullscreen /= Nothing then
        let
            game =
                model.game

            game_ =
                case Helpers.last entries of
                    Just entry ->
                        case entry of
                            LogChat _ _ ->
                                { game | chatOverlay = Just ( model.time, entry ) }

                            _ ->
                                game

                    Nothing ->
                        game
        in
        ( { model
            | game =
                List.foldl
                    (\entry g ->
                        if isChat entry then
                            { g | chatLog = List.append g.chatLog [ entry ] }

                        else
                            { g | gameLog = List.append g.gameLog [ entry ] }
                    )
                    game_
                    entries
          }
        , Cmd.none
        )

    else
        case model.game.table of
            Nothing ->
                ( model, Cmd.none )

            Just table ->
                ( model
                , updateChatCmd table entries
                )


updateChatCmd : Table -> List ChatLogEntry -> Cmd Types.Msg
updateChatCmd table entries =
    let
        ( chat, game ) =
            List.partition isChat entries
    in
    Cmd.batch
        [ if List.length chat > 0 then
            Dom.getViewportOf ("chatLog-" ++ table)
                |> Task.attempt (\info -> GameMsg <| Game.Types.ScrollChat ("chatLog-" ++ table) chat info)

          else
            Cmd.none
        , if List.length game > 0 then
            Dom.getViewportOf ("gameLog-" ++ table)
                |> Task.attempt (\info -> GameMsg <| Game.Types.ScrollChat ("gameLog-" ++ table) game info)

          else
            Cmd.none
        ]


update : Types.Model -> Game.Types.Model -> Game.Types.Msg -> ( Types.Model, Cmd Types.Msg )
update model game msg =
    case msg of
        ScrollChat id entries res ->
            ( { model
                | game =
                    List.foldl
                        (\entry g ->
                            if isChat entry then
                                { g | chatLog = List.append g.chatLog [ entry ] }

                            else
                                { g | gameLog = List.append g.gameLog [ entry ] }
                        )
                        model.game
                        entries
              }
            , Cmd.batch
                [ case res of
                    Err _ ->
                        consoleDebug <| "cannot scroll chat"

                    Ok info ->
                        if info.viewport.y + info.viewport.height + 10 >= info.scene.height then
                            Dom.setViewportOf id 0 5076944270305263616
                                |> Task.attempt
                                    (\_ -> Nop)

                        else
                            Cmd.none
                , case
                    List.foldl
                        (\entry maybe ->
                            case entry of
                                LogReceiveDice player count ->
                                    case game.player of
                                        Just me ->
                                            if player.id == me.id && count < player.gameStats.totalLands then
                                                Just <| player.gameStats.totalLands - count

                                            else
                                                maybe

                                        Nothing ->
                                            maybe

                                _ ->
                                    maybe
                        )
                        Nothing
                        entries
                  of
                    Just count ->
                        toastMessage
                            ("You missed "
                                ++ (String.fromInt <| count)
                                ++ " dice because you have disconnected lands!"
                            )
                        <|
                            Just 10000

                    Nothing ->
                        Cmd.none
                ]
            )

        ToggleDiceVisible visible ->
            let
                board = model.game.board
                options = board.boardOptions
                newBoard = { board | boardOptions = { options | diceVisible = visible }}
            in
            ( { model
                | game = { game | board = newBoard }
              }
            , Cmd.none
            )

        Hint point ->
            ( { model | game = { game | chartHinted = point } }, Cmd.none )


setUser : Model -> Types.LoggedUser -> Model
setUser model user =
    { model | player = findLoggedUserPlayer user model.players }


updatePlayers : Model -> List Player -> List Land.Color -> Model
updatePlayers model newPlayers removedColor =
    let
        player : Maybe Player
        player =
            findPlayer model newPlayers

        board =
            model.board

        board_ =
            { board
                | avatarUrls = Just <| List.map (\p -> ( p.color, p.picture )) newPlayers
            }

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
                                (\color acc ->
                                    Board.State.removeColor acc color
                                )
                                board_
                                removedColor

                        else
                            board_
                }

            else
                { model | players = newPlayers, board = board_ }
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


fetchTableTop : Types.Model -> Table -> ( Types.Model, Cmd Msg )
fetchTableTop model table =
    ( model, Backend.HttpCommands.tableStats model.backend table )
