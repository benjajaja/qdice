module Game.Chat exposing (..)

import Types exposing (Model, Msg(..))
import Backend.Types exposing (ChatLogEntry(..))
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Material.Card as Card
import Material.Options as Options exposing (cs, css, id)
import Material.Textfield as Textfield
import Material.Elevation
import Material.Icon as Icon
import Material.Button as Button


chatBox : Model -> Html Types.Msg
chatBox model =
    Card.view
        [ cs "chatbox"
        , Material.Elevation.e2
        ]
        [ Card.media [ cs "chatbox--log", Options.id model.game.chatBoxId ]
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
                )
                model.backend.chatLog
            )
        , Card.actions [ cs "chatbox--actions" ]
            [ Html.form [ onSubmit (SendChat "hi"), class "chatbox--actions-form" ]
                [ input model
                , Button.render
                    Types.Mdl
                    [ 0 ]
                    model.mdl
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


input : Model -> Html Types.Msg
input model =
    Textfield.render
        Types.Mdl
        [ 0 ]
        model.mdl
        [ Options.onInput InputChat
        , Textfield.value model.game.chatInput
        , cs "chatbox--actions-input"
        ]
        []
