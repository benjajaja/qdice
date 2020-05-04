module Games.Replayer exposing (gameReplayer, init, subscriptions, update)

import Board
import Board.Colors exposing (baseCssRgb)
import Board.State
import Board.Types exposing (BoardMove(..))
import Game.Types exposing (MapLoadError(..))
import Games.Replayer.Types exposing (..)
import Games.Types exposing (Game, GameEvent(..))
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
    , players = game.players
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
                [ Board.view m.board Nothing m.boardOptions [] |> Html.map Types.BoardMsg
                , div [] [ text <| "Round " ++ String.fromInt m.round ]
                , div [] <|
                    Helpers.join (text ", ") <|
                        List.indexedMap
                            (\i p ->
                                (if p.isBot then
                                    em

                                 else
                                    a
                                )
                                    [ style "color" (baseCssRgb p.color) ]
                                    [ text <|
                                        p.name
                                            ++ (if i == m.turnIndex then
                                                    "*"

                                                else
                                                    ""
                                               )
                                    ]
                            )
                            m.players
                , div [] [ text <| "Turn " ++ String.fromInt (m.step + 1) ]
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


applyEvent : ReplayerModel -> Int -> ReplayerModel
applyEvent model step =
    case List.drop step model.game.events |> List.head of
        Just event ->
            case event of
                Attack player from to ->
                    case Helpers.tupleCombine ( Land.findLand from model.board.map.lands, Land.findLand to model.board.map.lands ) of
                        Just ( fromLand, toLand ) ->
                            { model
                                | board =
                                    Board.State.updateLands model.board [] <| Just <| FromTo fromLand toLand
                            }

                        Nothing ->
                            model

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

                        turnIndex =
                            if
                                (List.drop model.turnIndex model.players |> List.head)
                                    /= (List.drop model.turnIndex players |> List.head)
                            then
                                model.turnIndex - 1

                            else
                                model.turnIndex
                    in
                    { model
                        | board = board
                        , players = players
                        , turnIndex = turnIndex
                    }

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
                    in
                    { model
                        | board =
                            case updates of
                                Just u ->
                                    Board.State.updateLands model.board u Nothing

                                Nothing ->
                                    model.board
                        , turnIndex = turnIndex
                        , round = round
                    }

                _ ->
                    model

        Nothing ->
            model
