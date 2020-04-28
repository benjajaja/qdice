module Dialog exposing (..)

import Helpers exposing (dataTestId)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import LoginDialog
import Types exposing (DialogStatus(..), DialogType(..), Model, Msg(..))


dialog : Model -> Html Msg
dialog model =
    case model.dialog of
        Show type_ ->
            backdrop model type_

        Hide ->
            text ""


backdrop : Model -> DialogType -> Html Msg
backdrop model type_ =
    div
        [ class "edLoginBackdrop" ]
        --, onClick <| HideDialog ]
        [ div
            [ class "edLoginDialog" ]
            [ case type_ of
                Login ->
                    LoginDialog.body model Nothing

                LoginJoin ->
                    LoginDialog.body model model.game.table

                Confirm callback msg ->
                    confirmBody model callback msg
            ]
        ]


confirmBody : Model -> (Model -> ( String, List (Html Msg) )) -> Msg -> Html Msg
confirmBody model callback msg =
    let
        ( title, message ) =
            callback model
    in
    div []
        [ h3 [] [ text title ]
        , p [ class "edDialog__text" ] <| message
        , div [ class "edDialog__confirm__buttons" ]
            [ button [ onClick HideDialog ] [ text "No" ]
            , button [ onClick msg ] [ text "Yes" ]
            ]
        ]
