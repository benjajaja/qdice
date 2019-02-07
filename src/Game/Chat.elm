module Game.Chat exposing (chatBox, chatPlayerTag, eliminationEmoji, eliminationReasonText, gameBox, input, maybeUserChatTag, playerTag, rollLine, toChatError)

import Board.Colors exposing (baseCssRgb)
import Game.Types exposing (ChatLogEntry(..), Model, PlayerAction(..), RollLog, actionToString)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (Error(..))
import Land exposing (Color)
import Board.Colors exposing (colorName)
import Icon
import Ordinal exposing (ordinal)
import Tables exposing (Table)
import Types exposing (Msg(..))


chatBox : String -> List Color -> List ChatLogEntry -> String -> Html Types.Msg
chatBox inputValue colors lines id_ =
    div [ class "chatbox" ] <|
        div [ class "chatbox--log", id id_ ]
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

                        LogJoin user ->
                            div [ class "chatbox--line--join" ]
                                [ Html.text <| maybeUserChatTag user ++ " joined"
                                ]

                        LogLeave user ->
                            div [ class "chatbox--line--leave" ]
                                [ Html.text <| maybeUserChatTag user ++ " left"
                                ]

                        _ ->
                            Html.text "^M"
                )
                lines
            )
            :: 
                    [ div [ class "chatbox--actions" ]
                        [ Html.form [ onSubmit (SendChat inputValue), class "chatbox--actions-form" ]
                            [ input inputValue
                            , button
                                [ type_ "submit"
                                , class "chatbox--actions-button"
                                ]
                                [ Icon.icon "keyboard_return" ]
                            ]
                        ]
                    ]


input : String -> Html Types.Msg
input value_ =
    textarea
        [ onInput InputChat
        , value value_
        , class "chatbox--actions-input"
        ]
        []


toChatError : Table -> PlayerAction -> Http.Error -> String
toChatError table action err =
    actionToString action
        ++ " failed: "
        ++ (case err of
                NetworkError ->
                    "No connection"

                Timeout ->
                    "Timed out (network)"

                BadStatus response ->
                    "Server error " ++ String.fromInt response.status.code ++ " " ++ response.status.message

                BadPayload error response ->
                    "Client error: " ++ error

                BadUrl error ->
                    "Missing URL: " ++ error
           )


gameBox : List ChatLogEntry -> String -> Html Types.Msg
gameBox lines id_ =
    div [ class "gamelogContainer" ]
        [ div [ class "gamelog", id id_ ] <|
            List.map
                (\c ->
                    case c of
                        LogChat _ _ _ ->
                            Html.text "\u{0000}"

                        LogJoin _ ->
                            Html.text "\u{0001}"

                        LogLeave _ ->
                            Html.text "\u{0002}"

                        LogError error ->
                            div [ class "chatbox--line--error" ]
                                [ Html.text <| error ]

                        LogRoll roll ->
                            rollLine roll

                        LogTurn user color ->
                            div [ class "chatbox--line--turn" ]
                                [ playerTag user color
                                , Html.text "'s turn"
                                ]

                        LogElimination user color position score reason ->
                            div [ class "chatbox--line--elimination" ]
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
                                , Html.text <| " with " ++ String.fromInt score ++ " ✪"
                                , Html.text <| " " ++ eliminationReasonText reason
                                ]

                        LogBegin table ->
                            div [ class "chatbox--line" ]
                                [ Html.text "At table "
                                , Html.strong [] [ Html.text <| table ]
                                ]
                )
            <|
                List.reverse <|
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
            [ Html.text <|
                roll.attacker
                    ++ (if roll.success then
                            " won over "

                        else
                            " lost against "
                       )
                    ++ roll.defender
                    ++ " "
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
    div [ class "chatbox--line--roll" ] text


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
            "(Killed by " ++ player.name ++ " for " ++ String.fromInt points ++ "✪)"

        Game.Types.ReasonOut turns ->
            "(Out for " ++ String.fromInt turns ++ " turns)"

        Game.Types.ReasonWin turns ->
            "(Last standing player after " ++ String.fromInt turns ++ " turns)"

        Game.Types.ReasonFlag position ->
            "(Flagged for " ++ ordinal position ++ ")"
