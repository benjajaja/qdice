module Games.Replayer exposing (gameReplayer, init, subscriptions, update)

import Array
import Board
import Board.Colors exposing (baseCssRgb)
import Board.State
import Board.Types exposing (BoardMove(..))
import Game.PlayerCard exposing (TurnPlayer)
import Game.Types exposing (GameStatus(..), MapLoadError(..), Player)
import Games.Replayer.Types exposing (..)
import Games.Types exposing (Game, GameEvent(..), GamePlayer)
import Helpers exposing (consoleDebug, dataTestId)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Icon
import Land exposing (LandUpdate)
import Maps
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
            Board.State.updateLands board game.lands Nothing
    in
    { board = board_
    , boardOptions =
        { diceVisible = True
        , showEmojis = False
        }
    , players = List.indexedMap (mapGamePlayer game.lands) game.players
    , turnIndex = 0
    , game = game
    , playing = False
    , step = 0
    , round = 1
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
        Time.every 100 (Types.ReplayerCmd << Tick)

    else
        Sub.none


gameReplayer : Maybe ReplayerModel -> Game -> Html Msg
gameReplayer model game =
    div [ class "edGameReplayer" ] <|
        case model of
            Just m ->
                [ div [ class "edPlayerChips" ] <|
                    List.map (Game.PlayerCard.view Playing) <|
                        List.take 4 <|
                            List.drop 4 <|
                                sortedPlayers m.turnIndex m.players
                , Board.view m.board Nothing m.boardOptions [] |> Html.map Types.BoardMsg
                , div [ class "edPlayerChips" ] <|
                    List.map (Game.PlayerCard.view Playing) <|
                        List.take 4 <|
                            sortedPlayers m.turnIndex m.players
                , div [] [ text <| "Round " ++ String.fromInt m.round ]
                , div [] [ text <| "Turn " ++ String.fromInt (m.step + 1) ++ " / " ++ String.fromInt m.turnIndex ]
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
    (case List.drop step model.game.events |> List.head of
        Just event ->
            case event of
                Attack player from to ->
                    case Helpers.tupleCombine ( Land.findLand from model.board.map.lands, Land.findLand to model.board.map.lands ) of
                        Just ( fromLand, toLand ) ->
                            ( { model
                                | board =
                                    Board.State.updateLands model.board [] <| Just <| FromTo fromLand toLand
                              }
                            , Nothing
                            )

                        Nothing ->
                            ( model, Nothing )

                Roll fromRoll toRoll ->
                    let
                        updates =
                            case model.board.move of
                                FromTo from to ->
                                    if List.sum fromRoll > List.sum toRoll then
                                        [ LandUpdate from.emoji from.color 1 from.capital
                                        , LandUpdate to.emoji from.color (from.points - 1) to.capital
                                        ]

                                    else
                                        [ LandUpdate from.emoji from.color 1 from.capital
                                        ]

                                _ ->
                                    []

                        board =
                            Board.State.updateLands model.board updates <| Just Idle

                        players =
                            List.filter
                                (\p ->
                                    List.filter (.color >> (==) p.color) board.map.lands
                                        |> List.length
                                        |> Helpers.flip (>) 0
                                )
                                model.players

                        isKill =
                            if List.length players /= List.length model.players then
                                Just 100

                            else
                                Nothing

                        turnIndex =
                            if
                                (List.drop model.turnIndex model.players |> List.head)
                                    /= (List.drop model.turnIndex players |> List.head)
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
                    )

                EndTurn id landDice reserveDice capitals player ->
                    let
                        updates =
                            landDice
                                |> List.map
                                    (\( emoji, dice ) ->
                                        case Land.findLand emoji model.board.map.lands of
                                            Just land ->
                                                Just <| LandUpdate emoji land.color (land.points + dice) land.capital

                                            Nothing ->
                                                Nothing
                                    )
                                |> Helpers.combine

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
                            case turnPlayer of
                                Just nextPlayer ->
                                    case nextPlayer.out of
                                        Just r ->
                                            let
                                                _ =
                                                    Debug.log "out/round" ( r, round, nextPlayer.name )
                                            in
                                            if round > r + 3 then
                                                List.filter (\p -> p.id /= nextPlayer.id) model.players

                                            else
                                                model.players

                                        Nothing ->
                                            model.players

                                Nothing ->
                                    model.players
                    in
                    ( { model
                        | board =
                            case updates of
                                Just u ->
                                    Board.State.updateLands model.board u Nothing

                                Nothing ->
                                    model.board
                        , turnIndex = turnIndex
                        , round = round
                        , players = players
                      }
                    , Nothing
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
                    ( { model | players = players }, Nothing )

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
                    ( { model | players = players }, Nothing )

                _ ->
                    ( model, Nothing )

        Nothing ->
            ( model, Nothing )
    )
        |> updatePlayers


updatePlayers : ( ReplayerModel, Maybe Int ) -> ReplayerModel
updatePlayers ( model, score ) =
    { model
        | players =
            List.indexedMap (mapPlayer model score) model.players
                |> updatePlayerPositions
                |> removeFlagged
    }


removeFlagged : List Player -> List Player
removeFlagged players =
    let
        length =
            List.length players

        cleared =
            List.filter
                (\p ->
                    case p.flag of
                        Just flag ->
                            not (length == flag && flag == p.gameStats.position)

                        Nothing ->
                            True
                )
                players
    in
    if List.length cleared == length then
        players

    else
        removeFlagged cleared


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
