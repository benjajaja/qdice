module Game.View exposing (view)

import Backend.Types exposing (ConnectionStatus(..))
import Board
import Game.Chat
import Game.Footer
import Game.PlayerCard as PlayerCard
import Game.State exposing (canHover)
import Game.Types exposing (PlayerAction(..), statusToString)
import Helpers exposing (dataTestId)
import Html exposing (..)
import Html.Attributes exposing (checked, class, disabled, href, style, type_)
import Html.Events exposing (onClick, preventDefaultOn)
import Icon
import Json.Decode exposing (succeed)
import LeaderBoard.View
import Ordinal exposing (ordinal)
import Time exposing (posixToMillis)
import Types exposing (Model, Msg(..), User(..))


view : Model -> Html Types.Msg
view model =
    let
        board =
            Board.view model.game.board
                (case model.game.board.hovered of
                    Just emoji ->
                        if canHover model.game emoji then
                            model.game.board.hovered
                            -- for Html.lazy ref-check

                        else
                            Nothing

                    Nothing ->
                        Nothing
                )
                |> Html.map BoardMsg
    in
    div [ class "edMainScreen" ]
        [ div [ class "edGameBoardWrapper" ]
            [ tableInfo model
            , header model
            , board
            , sitInModal model
            , boardFooter model
            ]
        , div [ class "edGame__meta" ]
            [ gameChat model
            , gameLog model
            ]
        , div [ class "edPlayerBoxes" ] <|
            playerBox model
                ++ leaderboardBox model
        , Game.Footer.footer model
        ]


header : Model -> Html.Html Types.Msg
header model =
    div [ class "edGameHeader" ]
        [ playerBar 4 model
        ]


boardFooter : Model -> Html.Html Types.Msg
boardFooter model =
    let
        toolbar =
            if model.screenshot then
                []

            else
                [ div [ class "edGameBoardFooter__content" ] <| seatButtons model
                ]
    in
    div [ class "edGameBoardFooter" ] <|
        playerBar 0 model
            :: toolbar


playerBar : Int -> Model -> Html Msg
playerBar dropCount model =
    div [ class "edPlayerChips" ] <|
        List.indexedMap (PlayerCard.view model dropCount) <|
            List.take 4 <|
                List.drop dropCount <|
                    model.game.players


seatButtons : Model -> List (Html.Html Types.Msg)
seatButtons model =
    if model.backend.status /= Online then
        [ button [ class "edButton edGameHeader__button", disabled True ] [ Icon.icon "signal_wifi_off" ]
        ]

    else
        case setButtonStates model of
            Nothing ->
                []

            Just { buttonLabel, msg, checkReady } ->
                List.concat
                    [ case checkReady of
                        Just ready ->
                            [ label
                                [ class "edCheckbox"
                                , onClick <| GameCmd <| ToggleReady <| not <| Maybe.withDefault ready model.game.isReady
                                , dataTestId "check-ready"
                                ]
                                [ Icon.icon <|
                                    if Maybe.withDefault ready model.game.isReady then
                                        "check_box"

                                    else
                                        "check_box_outline_blank"
                                , text "Ready"
                                ]
                            ]

                        Nothing ->
                            []
                    , if model.game.canFlag then
                        [ label
                            [ class "edCheckbox"
                            , onClick <| GameCmd <| Flag <| not <| Maybe.withDefault False model.game.flag
                            , dataTestId "check-flag"
                            ]
                            [ Icon.icon "flag"
                            , text <|
                                if model.game.playerPosition == List.length model.game.players then
                                    "Surrender"

                                else
                                    ordinal model.game.playerPosition
                            ]
                        ]

                      else
                        []
                    , [ button [ class "edButton edGameHeader__button", onClick msg, dataTestId "button-seat" ] [ text buttonLabel ]
                      ]
                    ]


setButtonStates : Model -> Maybe { buttonLabel : String, msg : Msg, checkReady : Maybe Bool }
setButtonStates model =
    case model.game.player of
        Just player ->
            Just <|
                if model.game.status == Game.Types.Playing then
                    if player.out then
                        { buttonLabel = "Sit in"
                        , msg = GameCmd SitIn
                        , checkReady = Nothing
                        }

                    else if model.game.hasTurn then
                        { buttonLabel = "End turn"
                        , msg = GameCmd EndTurn
                        , checkReady = Nothing
                        }

                    else
                        { buttonLabel = "Sit out"
                        , msg = GameCmd SitOut
                        , checkReady = Nothing
                        }

                else
                    { buttonLabel = "Leave"
                    , msg = GameCmd Leave
                    , checkReady = Just player.ready
                    }

        Nothing ->
            if model.game.status /= Game.Types.Playing then
                Just <|
                    case model.user of
                        Types.Anonymous ->
                            { buttonLabel = "Join"
                            , msg = ShowLogin Types.LoginShowJoin
                            , checkReady = Nothing
                            }

                        Types.Logged _ ->
                            { buttonLabel = "Join"
                            , msg = GameCmd Join
                            , checkReady = Nothing
                            }

            else
                Nothing


gameLog : Model -> Html.Html Types.Msg
gameLog model =
    Game.Chat.gameBox
        model.game.gameLog
    <|
        "gameLog-"
            ++ Maybe.withDefault "NOTABLE" model.game.table


gameChat : Model -> Html.Html Types.Msg
gameChat model =
    div [ class "chatboxContainer" ]
        [ Game.Chat.chatBox
            model.game.chatInput
            (List.map .color model.game.players)
            model.game.chatLog
          <|
            "chatLog-"
                ++ Maybe.withDefault "NOTABLE" model.game.table
        ]


sitInModal : Model -> Html.Html Types.Msg
sitInModal model =
    div
        [ if model.game.isPlayerOut then
            style "" ""

          else
            style "display" "none"
        , class "edGame__SitInModal"
        , Html.Events.onClick <| GameCmd SitIn
        ]
        [ button
            [ onClick <| GameCmd SitIn
            ]
            [ text "Sit in!" ]
        ]


tableInfo : Model -> Html Types.Msg
tableInfo model =
    div [ class "edGameStatus" ] <|
        List.concat
            [ case model.game.table of
                Just table ->
                    [ span [ class "edGameStatus__chip" ]
                        [ text "Table "
                        , span [ class "edGameStatus__chip--strong" ]
                            [ text <| table
                            ]
                        ]
                    , span [ class "edGameStatus__chip" ] <|
                        List.append
                            [ text ", "
                            , span [ class "edGameStatus__chip--strong" ]
                                [ text <|
                                    if model.game.playerSlots == 0 then
                                        "∅"

                                    else
                                        String.fromInt model.game.playerSlots
                                ]
                            , text " player game is "
                            , span [ class "edGameStatus__chip--strong", dataTestId "game-status" ]
                                [ text <| statusToString model.game.status ]
                            ]
                            (case model.game.gameStart of
                                Nothing ->
                                    [ text <| " round " ++ String.fromInt model.game.roundCount ]

                                Just timestamp ->
                                    [ text " starting in "
                                    , span [ class "edGameStatus__chip--strong" ]
                                        [ text <| String.fromInt (round <| toFloat timestamp - ((toFloat <| posixToMillis model.time) / 1000)) ++ "s" ]
                                    ]
                            )
                    ]

                Nothing ->
                    []
            , [ button [ class "edGameStatus__button edButton--icon", onClick RequestFullscreen ] [ Icon.icon "zoom_out_map" ] ]
            ]


playerBox : Model -> List (Html Msg)
playerBox model =
    [ div [ class "edPlayerBox" ]
        [ div [ class "edPlayerBox__inner" ] <|
            case model.user of
                Logged user ->
                    [ div [ class "edPlayerBox__Name" ] [ text user.name ]
                    , div [ class "edPlayerBox__stat" ] [ text "Points: ", text <| String.fromInt user.points ]
                    , div [ class "edPlayerBox__stat" ] [ text "Monthly rank: ", text <| ordinal user.rank ]
                    ]

                Anonymous ->
                    [ div [] [ text "You're not logged in." ]
                    , a
                        [ href "#"
                        , preventDefaultOn "click" <|
                            succeed <|
                                ( ShowLogin Types.LoginShow, False )
                        ]
                        [ text "Pick a username" ]
                    ]
        ]
    ]


leaderboardBox : Model -> List (Html Msg)
leaderboardBox model =
    [ div [ class "edLeaderboardBox" ]
        [ div [ class "edLeaderboardBox__inner" ]
            [ LeaderBoard.View.view 10 model ]
        ]
    ]
