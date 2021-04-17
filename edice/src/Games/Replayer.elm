module Games.Replayer exposing (gameReplayer, init, subscriptions, update)

import Array
import Board
import Board.Colors
import Board.State
import Board.Types exposing (BoardMove(..))
import Game.PlayerCard exposing (TurnPlayer)
import Game.Types exposing (GameStatus(..), MapLoadError(..), Player)
import Games.Replayer.Types exposing (..)
import Games.Types exposing (Game, GameEvent(..), GamePlayer, ShortGamePlayer)
import Helpers exposing (consoleDebug, dataTestId)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed
import Icon
import Land exposing (LandUpdate)
import Maps
import Ordinal exposing (ordinal)
import Snackbar
import Time
import Types exposing (GamesMsg(..), GamesSubRoute(..), Model, Msg)


init : Game -> ReplayerModel
init game =
    let
        map : Result MapLoadError Land.Map
        map =
            Maps.load game.map |> Result.mapError MapLoadError

        board =
            Board.init <| Result.withDefault Maps.emptyMap map

        board_ =
            Board.State.updateLands board game.lands Nothing []

        players =
            List.indexedMap (mapGamePlayer game.lands) game.players
    in
    { board =
        { board_
            | avatarUrls = Just <| List.map (\p -> ( p.color, p.picture )) players
        }
    , boardOptions =
        { diceVisible = True
        , showEmojis = True
        , height = Nothing
        }
    , players = players
    , turnIndex = 0
    , game = game
    , playing = False
    , step = 0
    , round = 1
    , log = []
    }


update : Model -> ReplayerCmd -> ( Model, Cmd Msg )
update model cmd =
    case model.replayer of
        Nothing ->
            ( model, consoleDebug "ReplayerCmd but not initialized" )

        Just m ->
            case cmd of
                StepOne ->
                    let
                        step =
                            m.step + 1

                        model_ =
                            { m | step = step }

                        replayer =
                            applyEvent model_ step
                    in
                    ( { model | replayer = Just replayer }, Cmd.none )

                StepN mstep ->
                    case mstep of
                        Just step ->
                            let
                                replayer_ =
                                    List.foldl
                                        (\i r ->
                                            applyEvent r i
                                        )
                                        (init m.game)
                                        (List.range 0 step)
                            in
                            ( { model | replayer = Just { replayer_ | step = step } }
                            , Cmd.none
                            )

                        Nothing ->
                            ( model, Snackbar.toastError "Cannot find turn" "" )

                TogglePlay ->
                    let
                        replayer =
                            { m | playing = not m.playing }
                    in
                    ( { model | replayer = Just replayer }, Cmd.none )

                Tick _ ->
                    ( { model
                        | replayer =
                            Maybe.map
                                (\replayer ->
                                    if replayer.playing then
                                        if replayer.step < List.length replayer.game.events - 1 then
                                            let
                                                step =
                                                    replayer.step + 1
                                            in
                                            applyEvent
                                                { replayer | step = step }
                                                step

                                        else
                                            { replayer | playing = False }

                                    else
                                        replayer
                                )
                                model.replayer
                      }
                    , Cmd.none
                    )


subscriptions : ReplayerModel -> Sub Msg
subscriptions model =
    if model.playing then
        Time.every 250 (Types.ReplayerCmd << Tick)

    else
        Sub.none


gameReplayer : Maybe ReplayerModel -> Game -> Html Msg
gameReplayer model game =
    div [ class "edGameReplayer" ] <|
        case model of
            Just m ->
                [ Html.Keyed.node "div" [ class "edPlayerChips" ] <|
                    List.map (Game.PlayerCard.view Playing) <|
                        List.take 4 <|
                            List.drop 4 <|
                                sortedPlayers m.turnIndex m.players
                , Board.view m.board Nothing m.boardOptions |> Html.map Types.BoardMsg
                , Html.Keyed.node "div" [ class "edPlayerChips" ] <|
                    List.map (Game.PlayerCard.view Playing) <|
                        List.take 4 <|
                            sortedPlayers m.turnIndex m.players
                , div [] [ text <| "Round " ++ String.fromInt m.round ++ ", step " ++ String.fromInt (m.step + 1) ]
                , div [ class "edGameReplayer__controls" ]
                    [ button [ onClick <| Types.ReplayerCmd <| TogglePlay ]
                        [ if not m.playing then
                            Icon.icon "play_arrow"

                          else
                            Icon.icon "pause"
                        ]
                    , button
                        (if m.step > 0 then
                            [ onClick <| Types.ReplayerCmd <| StepN <| Just 0 ]

                         else
                            [ disabled True ]
                        )
                        [ Icon.icon "first_page" ]
                    , button
                        (if m.step > 0 then
                            [ onClick <| Types.ReplayerCmd <| StepN <| Just <| m.step - 1 ]

                         else
                            [ disabled True ]
                        )
                        [ Icon.icon "chevron_left" ]
                    , button
                        (if m.step < List.length game.events - 1 then
                            [ onClick <| Types.ReplayerCmd <| StepOne ]

                         else
                            [ disabled True ]
                        )
                        [ Icon.icon "chevron_right" ]
                    , button
                        (if m.step < List.length game.events - 1 then
                            [ onClick <| Types.ReplayerCmd <| StepN <| Just <| List.length m.game.events - 1
                            , dataTestId "replayer-goto-end"
                            ]

                         else
                            [ disabled True ]
                        )
                        [ Icon.icon "last_page" ]
                    , input
                        [ type_ "range"
                        , class "edButton"
                        , Html.Attributes.min "0"
                        , Html.Attributes.max <| String.fromInt <| List.length m.game.events - 1
                        , value <|
                            String.fromInt m.step
                        , onInput <| (Types.ReplayerCmd << (StepN << String.toInt))
                        ]
                        []
                    ]
                , div [] [ text "Log:" ]
                , div [] <|
                    case
                        List.map
                            (\parts ->
                                div [ dataTestId "game-event" ] <|
                                    List.map
                                        (\part ->
                                            case part of
                                                LogPlayer p ->
                                                    text p.name

                                                LogNeutralPlayer ->
                                                    text "Neutral"

                                                LogString str ->
                                                    text str

                                                LogError err ->
                                                    text err
                                        )
                                        parts
                            )
                            m.log
                    of
                        [] ->
                            [ text "Stopped." ]

                        lines ->
                            lines
                ]

            Nothing ->
                []


mapGamePlayer : List LandUpdate -> Int -> GamePlayer -> Player
mapGamePlayer lands i p =
    let
        hisLands =
            List.filter (.color >> (==) p.color) lands
    in
    Player p.id
        p.name
        p.color
        p.picture
        Nothing
        { totalLands = List.length hisLands
        , connectedLands = 0
        , currentDice = List.foldl (.points >> (+)) 0 hisLands
        , position = i + 1
        , score = 0
        }
        0
        0
        0
        []
        Nothing
        False


sortedPlayers : Int -> List Player -> List TurnPlayer
sortedPlayers turnIndex players =
    let
        acc : Array.Array TurnPlayer
        acc =
            Array.initialize 8 (\i -> { player = Nothing, index = i, turn = Nothing, isUser = False })

        fold : ( Int, Player ) -> Array.Array TurnPlayer -> Array.Array TurnPlayer
        fold ( i, p ) array =
            Array.set (Board.Colors.colorIndex p.color - 1)
                { player =
                    Just p
                , index = i
                , turn =
                    if i == turnIndex then
                        Just 0.0

                    else
                        Nothing
                , isUser = False
                }
                array
    in
    List.foldl
        fold
        acc
        (List.indexedMap Tuple.pair players)
        |> Array.toList


applyEvent : ReplayerModel -> Int -> ReplayerModel
applyEvent model step =
    mapEvent model step
        |> updatePlayers


turnPlayerLogPart : List Player -> Int -> Maybe ShortGamePlayer -> ReplayerLogPart
turnPlayerLogPart players turnIndex mPlayer =
    let
        player =
            List.drop turnIndex players
                |> List.head
    in
    if mPlayer /= Nothing && Maybe.map .id mPlayer /= Maybe.map .id player then
        LogError <| "Bad turn index: " ++ (Maybe.map .name mPlayer |> Maybe.withDefault "nothing")

    else
        player
            |> Maybe.map LogPlayer
            |> Maybe.withDefault LogNeutralPlayer


shortPlayerLogPart : ShortGamePlayer -> ReplayerModel -> ReplayerLogPart
shortPlayerLogPart shortPlayer model =
    Helpers.find (.id >> (==) shortPlayer.id) model.players
        |> Maybe.map LogPlayer
        |> Maybe.withDefault (LogError <| "can't find player in board: " ++ shortPlayer.name)


mapEvent : ReplayerModel -> Int -> ( ReplayerModel, Maybe Int, ReplayerLogLine )
mapEvent model step =
    case List.drop step model.game.events |> List.head of
        Just event ->
            case event of
                Attack player from to ->
                    case Helpers.tupleCombine ( Land.findLand from model.board.map.lands, Land.findLand to model.board.map.lands ) of
                        Just ( fromLand, toLand ) ->
                            ( { model
                                | board =
                                    Board.State.updateLands model.board [] (Just <| FromTo fromLand toLand) []
                              }
                            , Nothing
                            , [ turnPlayerLogPart model.players model.turnIndex <| Just player
                              , LogString <| " attacked "
                              , Helpers.find (.color >> (==) toLand.color) model.players
                                    |> Maybe.map LogPlayer
                                    |> Maybe.withDefault LogNeutralPlayer
                              , LogString <| fromLand.emoji ++ "→" ++ toLand.emoji
                              ]
                            )

                        Nothing ->
                            ( model, Nothing, [ LogError "Attack occured but cannot find lands in board" ] )

                Roll fromRoll toRoll ->
                    let
                        isSuccess =
                            List.sum fromRoll > List.sum toRoll

                        ( updates, stealCount ) =
                            case model.board.move of
                                FromTo from to ->
                                    if isSuccess then
                                        let
                                            steal =
                                                Maybe.map .count to.capital
                                                    |> Maybe.map ((+) to.points)

                                            capitalUpdates =
                                                steal
                                                    |> Maybe.andThen
                                                        (\s ->
                                                            Helpers.find
                                                                (\l ->
                                                                    l.color == from.color && l.capital /= Nothing
                                                                )
                                                                model.board.map.lands
                                                                |> Maybe.map
                                                                    (\l ->
                                                                        [ LandUpdate l.emoji l.color l.points <|
                                                                            Maybe.map
                                                                                (\c ->
                                                                                    { c | count = c.count + s }
                                                                                )
                                                                                l.capital
                                                                        ]
                                                                    )
                                                        )
                                                    |> Maybe.withDefault []
                                        in
                                        ( [ LandUpdate from.emoji from.color 1 from.capital
                                          , LandUpdate to.emoji from.color (from.points - 1) Nothing
                                          ]
                                            ++ capitalUpdates
                                        , steal
                                        )

                                    else
                                        ( [ LandUpdate from.emoji from.color 1 from.capital
                                          ]
                                        , Nothing
                                        )

                                _ ->
                                    ( [], Nothing )

                        board =
                            Board.State.updateLands model.board updates (Just Idle) []

                        players =
                            List.filter
                                (\p ->
                                    List.filter (.color >> (==) p.color) board.map.lands
                                        |> List.length
                                        |> Helpers.flip (>) 0
                                )
                                model.players
                                |> List.map
                                    (\p ->
                                        Maybe.withDefault p <|
                                            Maybe.map
                                                (\match ->
                                                    if p == match then
                                                        { p | reserveDice = p.reserveDice + Maybe.withDefault 0 stealCount }

                                                    else
                                                        p
                                                )
                                            <|
                                                List.head <|
                                                    List.drop
                                                        model.turnIndex
                                                        model.players
                                    )

                        isKill =
                            if List.length players /= List.length model.players then
                                Just 100

                            else
                                Nothing

                        turnIndex =
                            if
                                (List.drop model.turnIndex model.players |> List.head |> Maybe.map .id)
                                    /= (List.drop model.turnIndex players |> List.head |> Maybe.map .id)
                            then
                                model.turnIndex - 1

                            else
                                model.turnIndex
                    in
                    ( { model
                        | board = board
                        , players = players
                        , turnIndex = turnIndex
                      }
                    , isKill
                    , [ turnPlayerLogPart players turnIndex Nothing
                      , LogString <|
                            if isSuccess then
                                " succeed"

                            else
                                " failed"
                      , LogString " ("
                      , LogString <| Helpers.toDiesEmojis fromRoll
                      , LogString " / "
                      , LogString <| Helpers.toDiesEmojis toRoll
                      , LogString ")"
                      ]
                    )

                EndTurn _ landDice reserveDice capitals player sitOut ->
                    let
                        updates =
                            landDice
                                |> List.map
                                    (\( emoji, dice ) ->
                                        case Land.findLand emoji model.board.map.lands of
                                            Just land ->
                                                Just <|
                                                    LandUpdate emoji land.color (land.points + dice) <|
                                                        Maybe.map (always { count = reserveDice }) land.capital

                                            Nothing ->
                                                Nothing
                                    )
                                |> Helpers.combine
                                |> Maybe.map
                                    ((++)
                                        (capitals
                                            |> List.map
                                                (\e ->
                                                    case Land.findLand e model.board.map.lands of
                                                        Just land ->
                                                            Just <| LandUpdate e land.color land.points <| Just { count = 0 }

                                                        Nothing ->
                                                            Nothing
                                                )
                                            |> Helpers.combine
                                            |> Maybe.withDefault []
                                        )
                                    )
                                |> Maybe.map
                                    (\list ->
                                        if List.any (.capital >> (/=) Nothing) list then
                                            List.map
                                                (\u ->
                                                    { u | capital = Maybe.map (\c -> { c | count = reserveDice }) u.capital }
                                                )
                                                list

                                        else
                                            list
                                                ++ (List.drop model.turnIndex model.players
                                                        |> List.head
                                                        |> Maybe.andThen
                                                            (\p ->
                                                                Helpers.find
                                                                    (\l ->
                                                                        l.color == p.color && l.capital /= Nothing
                                                                    )
                                                                    model.board.map.lands
                                                                    |> Maybe.map
                                                                        (\l ->
                                                                            [ LandUpdate l.emoji l.color l.points <|
                                                                                Maybe.map
                                                                                    (\c ->
                                                                                        { c | count = reserveDice }
                                                                                    )
                                                                                    l.capital
                                                                            ]
                                                                        )
                                                            )
                                                        |> Maybe.withDefault []
                                                   )
                                    )

                        turnIndex =
                            if model.turnIndex < List.length model.players - 1 then
                                model.turnIndex + 1

                            else
                                0

                        round =
                            if turnIndex == 0 then
                                model.round + 1

                            else
                                model.round

                        turnPlayer =
                            List.drop turnIndex model.players |> List.head

                        players =
                            (case turnPlayer of
                                Just nextPlayer ->
                                    case nextPlayer.out of
                                        Just r ->
                                            if round > r + 3 then
                                                List.filter (\p -> p.id /= nextPlayer.id) model.players

                                            else
                                                model.players

                                        Nothing ->
                                            model.players

                                Nothing ->
                                    model.players
                            )
                                |> List.map
                                    (\p ->
                                        if p.id == player.id then
                                            { p
                                                | out =
                                                    if sitOut then
                                                        Just model.round

                                                    else
                                                        p.out
                                                , reserveDice = reserveDice
                                            }

                                        else
                                            p
                                    )
                    in
                    ( { model
                        | board =
                            case updates of
                                Just u ->
                                    Board.State.updateLands model.board u Nothing []

                                Nothing ->
                                    model.board
                        , turnIndex = turnIndex
                        , round = round
                        , players = players
                      }
                    , Nothing
                    , [ turnPlayerLogPart players turnIndex Nothing, LogString "'s turn" ]
                    )

                Flag player position ->
                    let
                        players =
                            List.map
                                (\p ->
                                    if p.id == player.id then
                                        { p | flag = Just position }

                                    else
                                        p
                                )
                                model.players
                    in
                    ( { model | players = players }
                    , Nothing
                    , [ shortPlayerLogPart player model
                      , LogString <|
                            " flagged "
                                ++ ordinal
                                    position
                      ]
                    )

                SitOut player ->
                    let
                        players =
                            List.map
                                (\p ->
                                    if p.id == player.id then
                                        { p | out = Just model.round }

                                    else
                                        p
                                )
                                model.players
                    in
                    ( { model | players = players }
                    , Nothing
                    , [ shortPlayerLogPart player model
                      , LogString " sat out"
                      ]
                    )

                SitIn player ->
                    let
                        players =
                            List.map
                                (\p ->
                                    if p.id == player.id then
                                        { p | out = Nothing }

                                    else
                                        p
                                )
                                model.players
                    in
                    ( { model | players = players }
                    , Nothing
                    , [ shortPlayerLogPart player model
                      , LogString " sat in"
                      ]
                    )

                EndGame winner turns ->
                    ( model
                    , Nothing
                    , [ Maybe.map (\p -> shortPlayerLogPart p model) winner |> Maybe.withDefault LogNeutralPlayer
                      , LogString <| " won the game after " ++ String.fromInt turns ++ " turns"
                      ]
                    )

                Chat player message ->
                    ( model
                    , Nothing
                    , [ shortPlayerLogPart player model
                      , LogString <| ": " ++ message
                      ]
                    )

                ToggleReady player ready ->
                    ( model
                    , Nothing
                    , [ shortPlayerLogPart player model
                      , LogString <|
                            " "
                                ++ (if ready then
                                        "checked"

                                    else
                                        "unchecked"
                                   )
                                ++ " ready"
                      ]
                    )

                Start ->
                    ( model, Nothing, [ LogString <| "Game started" ] )

                Unknown eventStr ->
                    ( model, Nothing, [ LogString <| "Unhandled event: " ++ eventStr ] )

        Nothing ->
            ( model, Nothing, [ LogError "no more events" ] )


updatePlayers : ( ReplayerModel, Maybe Int, ReplayerLogLine ) -> ReplayerModel
updatePlayers ( model, score, line ) =
    { model
        | players =
            List.indexedMap (mapPlayer model score) model.players
                |> updatePlayerPositions
        , log = line :: model.log
    }
        |> removeFlagged


removeFlagged : ReplayerModel -> ReplayerModel
removeFlagged model =
    let
        players =
            removeFlaggedPlayers model.players

        removedColors =
            List.filter (.id >> Helpers.flip List.member (List.map .id players) >> not) model.players
                |> List.map .color

        board_ =
            if List.length removedColors > 0 then
                Board.State.updateLands model.board
                    (List.foldl
                        (\color updates ->
                            updates
                                ++ (List.filter (.color >> (==) color) model.board.map.lands
                                        |> List.map (\l -> LandUpdate l.emoji Land.Neutral l.points Nothing)
                                   )
                        )
                        []
                        removedColors
                    )
                    (Just model.board.move)
                    []

            else
                model.board
    in
    { model | players = players, board = board_ }


removeFlaggedPlayers : List Player -> List Player
removeFlaggedPlayers players =
    let
        length =
            List.length players

        cleared =
            List.filter
                (\p ->
                    case p.flag of
                        Just flag ->
                            not (length == flag)

                        Nothing ->
                            True
                )
                players
    in
    if List.length cleared == length then
        players

    else
        removeFlaggedPlayers cleared


mapPlayer : ReplayerModel -> Maybe Int -> Int -> Player -> Player
mapPlayer model score i p =
    let
        hisLands =
            List.filter (.color >> (==) p.color) model.board.map.lands

        stats =
            p.gameStats
    in
    { p
        | gameStats =
            { stats
                | totalLands = List.length hisLands
                , currentDice = List.foldl (.points >> (+)) 0 hisLands
                , score =
                    if score /= Nothing && i == model.turnIndex then
                        p.gameStats.score + Maybe.withDefault 0 score

                    else
                        p.gameStats.score
            }
    }


updatePlayerPositions : List Player -> List Player
updatePlayerPositions players =
    let
        sorted =
            List.indexedMap Tuple.pair players
                |> List.sortWith
                    (\( ai, a ) ( bi, b ) ->
                        if a.gameStats.totalLands == b.gameStats.totalLands then
                            if a.gameStats.currentDice == b.gameStats.currentDice then
                                if ai > bi then
                                    GT

                                else
                                    LT

                            else if a.gameStats.currentDice > b.gameStats.currentDice then
                                GT

                            else
                                LT

                        else if a.gameStats.totalLands > b.gameStats.totalLands then
                            GT

                        else
                            LT
                    )
                |> List.reverse
    in
    sorted
        |> List.map
            (\( i, p ) ->
                let
                    stats =
                        p.gameStats
                in
                ( i, { p | gameStats = { stats | position = i + 1 } } )
            )
        |> List.sortBy Tuple.first
        |> List.map Tuple.second
