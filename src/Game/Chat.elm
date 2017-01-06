module Game.Chat exposing (..)

import Types exposing (Model, Msg(..))
import Game.Types exposing (Msg(..))
import Backend.Types exposing (ChatLogEntry(..))
import Html exposing (..)
import Html.App
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Material.Card as Card
import Material.Options as Options exposing (cs, css)
import Material.Textfield as Textfield


chatBox : Model -> Html Types.Msg
chatBox model =
    Card.view [ cs "chatbox" ]
        [ Card.text []
            [ div [ class "chatbox--log" ]
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
            ]
        , Card.actions []
            [ Html.form [ onSubmit (Types.GameMsg <| SendChat "hi") ]
                [ input model
                , button [ type' "submit", hidden True ] [ text "->" ]
                ]
            ]
        ]


input : Model -> Html Types.Msg
input model =
    Textfield.render
        Types.Mdl
        [ 0 ]
        model.mdl
        [ Textfield.onInput (Types.GameMsg << InputChat)
        ]
