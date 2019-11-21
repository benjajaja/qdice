module Game.View exposing (view)

import Backend.Types exposing (ConnectionStatus(..))
import Board
import Game.Chat
import Game.Footer
import Game.PlayerCard as PlayerCard
import Game.State exposing (findUserPlayer)
import Game.Types exposing (PlayerAction(..), statusToString)
import Helpers exposing (dataTestId)
import Html exposing (..)
import Html.Attributes exposing (checked, class, disabled, style, type_)
import Html.Events exposing (onClick)
import Icon
import Time exposing (posixToMillis)
import Types exposing (Model, Msg(..))


view : Model -> Html Types.Msg
view model =
    let
        board =
            Board.view model.game.board
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
        List.indexedMap (PlayerCard.view model) <|
            List.take 4 <|
                List.drop dropCount <|
                    model.game.players


seatButtons : Model -> List (Html.Html Types.Msg)
seatButtons model =
    if model.backend.status /= Online then
        [ button [ class "edButton edGameHeader__button", disabled True ] [ Icon.icon "signal_wifi_off" ]
        ]

    else
        let
            { buttonLabel, msg, checkReady } =
                setButtonStates model
        in
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
            , [ button [ class "edButton edGameHeader__button", onClick msg, dataTestId "button-seat" ] [ text buttonLabel ]
              ]
            ]


setButtonStates model =
    case findUserPlayer model.user model.game.players of
        Just player ->
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
        case model.game.table of
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
