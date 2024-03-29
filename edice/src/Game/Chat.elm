module Game.Chat exposing (chatBox, chatLine, chatPlayerTag, eliminationEmoji, eliminationReasonText, gameBox, input, maybeUserChatTag, playerTag, rollLine)

import Board.Colors exposing (baseCssRgb, colorName)
import Game.Types exposing (ChatLogEntry(..), EliminationReason, PlayerAction(..), RollLog)
import Helpers exposing (dataTestId, pointsSymbol)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Keyed
import Http exposing (Error(..))
import Icon
import Land exposing (Color)
import Ordinal exposing (ordinal)
import Routing.String exposing (routeToString)
import Types exposing (GamesSubRoute(..), Msg(..), Route(..), User(..))


chatBox : String -> List ChatLogEntry -> String -> User -> Html Types.Msg
chatBox inputValue lines id_ user =
    div [ class "chatbox" ] <|
        [ div [ class "chatbox--log", id id_ ]
            (List.map
                chatLine
                lines
            )
        , case user of
            Anonymous ->
                text ""

            Logged _ ->
                div [ class "chatbox--actions" ]
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


chatLine : ChatLogEntry -> Html Types.Msg
chatLine line =
    case line of
        LogChat chatter message ->
            div [ class "chatbox--line--chat" ]
                [ chatPlayerTag chatter
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
        [ Html.Keyed.node "div" [ class "gamelog", id id_ ] <|
            List.indexedMap
                (\i c ->
                    ( String.fromInt i
                    , case c of
                        LogChat _ _ ->
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
                                [ playerTag player.name <| Just player.color
                                , Html.text " joined the game"
                                ]

                        LogLeave player ->
                            div [ class "chatbox--line--leave", dataTestId "logline-leave" ]
                                [ playerTag player.name <| Just player.color
                                , Html.text " left the game"
                                ]

                        LogTakeover player replaced ->
                            div [ class "chatbox--line--takeover", dataTestId "logline-takeover" ]
                                [ playerTag player.name <| Just player.color
                                , Html.text " has taken over "
                                , playerTag replaced.name <| Just replaced.color
                                ]

                        LogRoll roll ->
                            rollLine roll

                        LogTurn user color ->
                            div [ class "chatbox--line--turn", dataTestId "logline-turn" ]
                                [ playerTag user <| Just color
                                , Html.text "'s turn"
                                ]

                        LogElimination user color position score reason ->
                            div [ class "chatbox--line--elimination", dataTestId "logline-elimination" ]
                                [ eliminationEmoji reason
                                , Html.text " "
                                , playerTag user <| Just color
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
                                [ playerTag player.name <| Just player.color
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

                        LogEndGame table id ->
                            div [ class "chatbox--line--end" ]
                                [ a
                                    [ href <| routeToString False <| GamesRoute <| GameId table id
                                    ]
                                    [ Html.text <| "Watch replay of game #" ++ String.fromInt id ]
                                ]
                    )
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


chatPlayerTag : Maybe Game.Types.Chatter -> Html Types.Msg
chatPlayerTag chatter =
    case chatter of
        Just c ->
            playerTag c.name c.color

        Nothing ->
            Html.span [] [ Html.text "Anonymous" ]


playerTag : String -> Maybe Color -> Html Types.Msg
playerTag name color =
    Html.span
        (case color of
            Just c ->
                [ class <| "chatbox__tag__player chatbox__tag__player--" ++ colorName c
                , style "color" <| baseCssRgb c
                ]

            Nothing ->
                []
        )
        [ Html.text <| name ]


rollLine : RollLog -> Html Types.Msg
rollLine roll =
    let
        text =
            [ playerTag roll.attacker <| Just roll.attackerColor
            , Html.text <|
                if roll.success then
                    " won over "

                else
                    " lost against "
            , playerTag roll.defender <| Just roll.defenderColor
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
                    ++ (if roll.success then
                            " → "

                        else
                            " ↩ "
                       )
                    ++ roll.defendDiesEmojis
            ]
                ++ (case roll.steal of
                        Just n ->
                            [ Html.text <|
                                " stealing "
                                    ++ String.fromInt n
                                    ++ " extra dice from capital"
                            ]

                        Nothing ->
                            []
                   )
    in
    div [ class "chatbox--line--roll", dataTestId "logline-roll" ] text


eliminationEmoji : EliminationReason -> Html msg
eliminationEmoji reason =
    Html.text <|
        case reason of
            Game.Types.ReasonDeath _ _ ->
                "☠"

            Game.Types.ReasonOut _ ->
                "💤"

            Game.Types.ReasonWin _ ->
                "🏆"

            Game.Types.ReasonFlag _ _ ->
                "🏳"


eliminationReasonText : EliminationReason -> String
eliminationReasonText reason =
    case reason of
        Game.Types.ReasonDeath player points ->
            "(Killed by " ++ player.name ++ " for " ++ String.fromInt points ++ pointsSymbol ++ ")"

        Game.Types.ReasonOut turns ->
            "(Out for " ++ String.fromInt turns ++ " turns)"

        Game.Types.ReasonWin turns ->
            "(Last standing player after " ++ String.fromInt turns ++ " turns)"

        Game.Types.ReasonFlag position to ->
            case to of
                Nothing ->
                    "(Flagged for " ++ ordinal position ++ ")"

                Just ( player, points ) ->
                    "(Flagged for "
                        ++ ordinal position
                        ++ " under "
                        ++ player.name
                        ++ " for "
                        ++ String.fromInt points
                        ++ pointsSymbol
                        ++ ")"
