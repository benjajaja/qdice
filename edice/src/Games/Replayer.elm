module Games.Replayer exposing (gameReplayer, init, update)

import Board
import Board.State
import Board.Types exposing (BoardMove(..))
import Game.Types exposing (MapLoadError(..))
import Games.Replayer.Types exposing (..)
import Games.Types exposing (Game, GameEvent(..), GamePlayer)
import Helpers exposing (consoleDebug)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Icon
import Land exposing (LandUpdate)
import Maps
import Tables exposing (Table)
import Types exposing (GamesMsg(..), GamesSubRoute(..), Model, Msg(..))


init : Game -> ReplayerModel
init game =
    let
        map : Result MapLoadError Land.Map
        map =
            case Maps.mapFromTable game.tag of
                Ok m ->
                    Maps.load m |> Result.mapError MapLoadError

                Err err2 ->
                    Err BadTableError

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
    , players = []
    , game = game
    , playing = False
    , step = 0
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

                TogglePlay ->
                    let
                        replayer =
                            { m | playing = not m.playing }
                    in
                    ( { model | replayer = Just replayer }, Cmd.none )


gameReplayer : Maybe ReplayerModel -> Game -> Html Msg
gameReplayer model game =
    div [ class "edGameReplayer" ] <|
        case model of
            Just m ->
                [ Board.view m.board Nothing m.boardOptions [] |> Html.map BoardMsg
                , div [] [ text <| "Turn " ++ String.fromInt (m.step + 1) ]
                , div []
                    -- [ button [ onClick <| ReplayerCmd <| TogglePlay ]
                    -- [ if not m.playing then
                    -- Icon.icon "play_arrow"
                    --
                    -- else
                    -- Icon.icon "pause"
                    -- ]
                    -- , button [ onClick <| ReplayerCmd <| Step 0 ] [ Icon.icon "first_page" ]
                    -- , button
                    -- (if m.step > 0 then
                    -- [ onClick <| ReplayerCmd <| Step <| m.step - 1 ]
                    --
                    -- else
                    -- [ disabled True ]
                    -- )
                    -- [ Icon.icon "chevron_left" ]
                    [ button
                        (if m.step < List.length game.events then
                            [ onClick <| ReplayerCmd <| StepOne ]

                         else
                            [ disabled True ]
                        )
                        [ Icon.icon "chevron_right" ]

                    -- , button [ onClick <| ReplayerCmd <| Step <| List.length game.events - 1 ] [ Icon.icon "last_page" ]
                    ]
                ]

            Nothing ->
                []


applyEvent : ReplayerModel -> Int -> ReplayerModel
applyEvent model step =
    case List.drop step model.game.events |> List.head of
        Just event ->
            let
                board =
                    case event of
                        Attack player from to ->
                            case Helpers.tupleCombine ( Land.findLand from model.board.map.lands, Land.findLand to model.board.map.lands ) of
                                Just ( fromLand, toLand ) ->
                                    Board.State.updateLands model.board [] <| Just <| FromTo fromLand toLand

                                Nothing ->
                                    model.board

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
                            in
                            Board.State.updateLands model.board updates <| Just Idle

                        _ ->
                            model.board
            in
            { model | board = board }

        Nothing ->
            model
