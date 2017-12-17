module Game.Chat exposing (..)

import Types exposing (Msg(..))
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http exposing (Error(..))
import Material
import Material.Card as Card
import Material.Options as Options exposing (cs, css, id)
import Material.Textfield as Textfield
import Material.Elevation
import Material.Icon as Icon
import Material.Button as Button
import Game.Types exposing (PlayerAction(..), ChatLogEntry(..), RollLog, Model)
import Tables exposing (Table)


chatBox : Bool -> String -> Material.Model -> List ChatLogEntry -> String -> Html Types.Msg
chatBox hasInput inputValue mdl lines id =
    Card.view [ cs "chatbox", Material.Elevation.e2 ] <|
        Card.media [ cs "chatbox--log", Options.id id ]
            (List.map
                (\c ->
                    case c of
                        LogChat user message ->
                            div [ class "chatbox--line--chat" ]
                                [ Html.span []
                                    [ Html.text <| user ++ ":" ]
                                , Html.span []
                                    [ Html.text message ]
                                ]

                        LogJoin user ->
                            div [ class "chatbox--line--join" ]
                                [ Html.text <| user ++ " joined" ]

                        LogLeave user ->
                            div [ class "chatbox--line--leave" ]
                                [ Html.text <| user ++ " left" ]

                        LogError error ->
                            div [ class "chatbox--line--error" ]
                                [ Html.text <| error ]

                        LogRoll roll ->
                            rollLine roll
                )
                lines
            )
            :: (if hasInput then
                    [ Card.actions [ cs "chatbox--actions" ]
                        [ Html.form [ onSubmit (SendChat "hi"), class "chatbox--actions-form" ]
                            [ input mdl inputValue
                            , Button.render
                                Types.Mdl
                                [ 0 ]
                                mdl
                                [ Button.primary
                                , Button.colored
                                , Button.ripple
                                , Button.type_ "submit"
                                , cs "chatbox--actions-button"
                                ]
                                [ Icon.i "keyboard_return" ]
                            ]
                        ]
                    ]
                else
                    []
               )


input : Material.Model -> String -> Html Types.Msg
input mdl value =
    Textfield.render
        Types.Mdl
        [ 0 ]
        mdl
        [ Options.onInput InputChat
        , Textfield.value value
        , cs "chatbox--actions-input"
        ]
        []


toChatError : Table -> PlayerAction -> Http.Error -> String
toChatError table action err =
    (toString action)
        ++ " failed: "
        ++ (case err of
                NetworkError ->
                    "No connection"

                Timeout ->
                    "Timed out (network)"

                BadStatus response ->
                    "Server error " ++ (toString response.status.code) ++ " " ++ response.status.message

                BadPayload error response ->
                    "Client error: " ++ error

                BadUrl error ->
                    "Missing URL: " ++ error
           )


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
                    ++ (toString roll.attackRoll)
                    ++ " to "
                    ++ (toString roll.defendRoll)
                    ++ " ("
                    ++ (roll.attackDiesEmojis)
                    ++ " -> "
                    ++ (roll.defendDiesEmojis)
                    ++ ")"
            ]
    in
        div [ class "chatbox--line--roll" ] text
