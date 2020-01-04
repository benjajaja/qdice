module Game.Chat exposing (chatBox, chatPlayerTag, eliminationEmoji, eliminationReasonText, gameBox, input, maybeUserChatTag, playerTag, rollLine)

import Board.Colors exposing (baseCssRgb, colorName)
import Game.Types exposing (ChatLogEntry(..), Player, PlayerAction(..), RollLog, userColor)
import Helpers exposing (dataTestId, pointsSymbol)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (Error(..))
import Icon
import Land exposing (Color)
import Ordinal exposing (ordinal)
import Types exposing (Msg(..))


chatBox : String -> List Color -> List ChatLogEntry -> String -> Html Types.Msg
chatBox inputValue colors lines id_ =
    div [ class "chatbox" ] <|
        [ div [ class "chatbox--log", id id_ ]
            (List.map
                (\c ->
                    case c of
                        LogChat user color message ->
                            div [ class "chatbox--line--chat" ]
                                [ chatPlayerTag user color
                                , Html.text ": "
                                , Html.span []
                                    [ Html.text message ]
                                ]

                        LogEnter user ->
                            div [ class "chatbox--line--enter" ]
                                [ Html.text <| maybeUserChatTag user ++ " is here"
                                ]

                        LogExit user ->
                            div [ class "chatbox--line--exit" ]
                                [ Html.text <| maybeUserChatTag user ++ " is gone"
                                ]

                        _ ->
                            Html.text "^M"
                )
                lines
            )
        , div [ class "chatbox--actions" ]
            [ Html.form [ onSubmit (SendChat inputValue), class "chatbox--actions-form" ]
                [ input inputValue
                , button
                    [ type_ "submit"
                    , class "chatbox--actions-button edButton"
                    , attribute "aria-label" "submit chat message"
                    ]
                    [ Icon.icon "keyboard_return" ]
                ]
            ]
        ]


input : String -> Html Types.Msg
input value_ =
    Html.input
        [ onInput InputChat
        , value value_
        , class "chatbox--actions-input"
        , attribute "aria-label" "chat prompt"
        , placeholder "say..."
        ]
        []


gameBox : List ChatLogEntry -> String -> Html Types.Msg
gameBox lines id_ =
    div [ class "gamelogContainer" ]
        [ div [ class "gamelog", id id_ ] <|
            List.map
                (\c ->
                    case c of
                        LogChat _ _ _ ->
                            Html.text "ERRchat"

                        LogEnter _ ->
                            Html.text "ERRenter"

                        LogExit _ ->
                            Html.text "ERRexit"

                        LogError error ->
                            div [ class "chatbox--line--error" ]
                                [ Html.text <| error ]

                        LogJoin player ->
                            div [ class "chatbox--line--join", dataTestId "logline-join" ]
                                [ playerTag player.name player.color
                                , Html.text " joined the game"
                                ]

                        LogLeave player ->
                            div [ class "chatbox--line--leave", dataTestId "logline-leave" ]
                                [ playerTag player.name player.color
                                , Html.text " left the game"
                                ]

                        LogRoll roll ->
                            rollLine roll

                        LogTurn user color ->
                            div [ class "chatbox--line--turn", dataTestId "logline-turn" ]
                                [ playerTag user color
                                , Html.text "'s turn"
                                ]

                        LogElimination user color position score reason ->
                            div [ class "chatbox--line--elimination", dataTestId "logline-elimination" ]
                                [ eliminationEmoji reason
                                , Html.text " "
                                , playerTag user color
                                , Html.strong []
                                    [ Html.text <|
                                        if position == 1 then
                                            " won the game!"

                                        else
                                            " finished " ++ ordinal position
                                    ]
                                , Html.text <| " with " ++ String.fromInt score ++ " " ++ pointsSymbol
                                , Html.text <| " " ++ eliminationReasonText reason
                                ]

                        LogBegin table ->
                            div [ class "chatbox--line" ]
                                [ Html.text "At table "
                                , Html.strong [] [ Html.text <| table ]
                                ]

                        LogReceiveDice player count ->
                            div [ class "chatbox--line--receive" ]
                                [ playerTag player.name player.color
                                , Html.text <|
                                    if player.gameStats.connectedLands < player.gameStats.totalLands then
                                        " got "
                                            ++ String.fromInt count
                                            ++ " dice, missing "
                                            ++ (String.fromInt <| player.gameStats.totalLands - player.gameStats.connectedLands)
                                            ++ " disconnected lands"

                                    else
                                        " got " ++ String.fromInt count ++ " dice"
                                ]
                )
            <|
                lines
        ]


maybeUserChatTag : Maybe Game.Types.User -> String
maybeUserChatTag user =
    case user of
        Just u ->
            u

        Nothing ->
            "🕵️ Anonymous"


chatPlayerTag : Maybe Game.Types.User -> Color -> Html Types.Msg
chatPlayerTag user color =
    case user of
        Just name ->
            playerTag name color

        Nothing ->
            Html.span [] [ Html.text "Anonymous" ]


playerTag : Game.Types.User -> Color -> Html Types.Msg
playerTag name color =
    Html.span
        [ class <| "chatbox__tag__player chatbox__tag__player--" ++ colorName color
        , style "color" (baseCssRgb color)
        ]
        [ Html.text <| name ]


rollLine : RollLog -> Html Types.Msg
rollLine roll =
    let
        text =
            [ playerTag roll.attacker roll.attackerColor
            , Html.text <|
                if roll.success then
                    " won over "

                else
                    " lost against "
            , playerTag roll.defender roll.defenderColor
            , Html.text <|
                " "
                    ++ String.fromInt roll.attackRoll
                    ++ (if roll.success then
                            " → "

                        else
                            " ↩ "
                       )
                    ++ String.fromInt roll.defendRoll
                    ++ " ("
                    ++ (String.fromInt <| roll.attackDiceCount * 6)
                    ++ "/"
                    ++ (String.fromInt <| roll.defendDiceCount * 6)
                    ++ ")"
                    ++ ": "
                    ++ roll.attackDiesEmojis
                    ++ " → "
                    ++ roll.defendDiesEmojis
            ]
    in
    div [ class "chatbox--line--roll", dataTestId "logline-roll" ] text


eliminationEmoji reason =
    Html.text <|
        case reason of
            Game.Types.ReasonDeath _ _ ->
                "☠"

            Game.Types.ReasonOut _ ->
                "💤"

            Game.Types.ReasonWin _ ->
                "🏆"

            Game.Types.ReasonFlag _ ->
                "🏳"


eliminationReasonText reason =
    case reason of
        Game.Types.ReasonDeath player points ->
            "(Killed by " ++ player.name ++ " for " ++ String.fromInt points ++ pointsSymbol ++ ")"

        Game.Types.ReasonOut turns ->
            "(Out for " ++ String.fromInt turns ++ " turns)"

        Game.Types.ReasonWin turns ->
            "(Last standing player after " ++ String.fromInt turns ++ " turns)"

        Game.Types.ReasonFlag position ->
            "(Flagged for " ++ ordinal position ++ ")"
