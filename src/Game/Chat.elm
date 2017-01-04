module Game.Chat exposing (..)

import Types exposing (Model, Msg)
import Game.Types exposing (Msg(..))
import Backend.Types exposing (ChatLogEntry(..))
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)


chatBox : Model -> Html Game.Types.Msg
chatBox model =
    div []
        [ div []
            (List.map
                (\c ->
                    div []
                        [ case c of
                            LogChat user message ->
                                Html.text <| user ++ ": " ++ message

                            _ ->
                                Html.text "other"
                        ]
                )
                model.backend.chatLog
            )
        , Html.form [ onSubmit (SendChat "hi") ]
            [ input
                [ placeholder "say something"
                , value model.game.chatInput
                , onInput InputChat
                ]
                []
            , button [ type' "submit", hidden True ] [ text "->" ]
            ]
        ]
