module LoginDialog exposing (loginDialog)

import Helpers exposing (dataTestId)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import Types exposing (AuthNetwork(..), LoginDialogStatus(..), Model, Msg(..))


loginDialog : Model -> Html Msg
loginDialog model =
    case model.showLoginDialog of
        LoginHide ->
            text ""

        _ ->
            div
                [ class "edLoginBackdrop" ]
                [ div
                    [ class "edLoginDialog", dataTestId "login-dialog" ]
                    [ body model ]
                ]


body : Model -> Html Msg
body model =
    div []
        [ div
            [ class "edLoginDialog__social" ]
            [ div []
                [ text "One-click sign-in:" ]
            , button
                [ onClick <|
                    Authorize
                        { network = Google
                        , table =
                            case model.showLoginDialog of
                                LoginShowJoin ->
                                    model.game.table

                                _ ->
                                    Nothing
                        , addTo = Nothing
                        }
                , class "edLoginSocial edLoginSocial--google"
                ]
                [ img [ src "assets/social_icons/google.svg" ] []
                , text "Sign in with Google"
                ]
            , button
                [ onClick <|
                    Authorize
                        { network = Reddit
                        , table =
                            case model.showLoginDialog of
                                LoginShowJoin ->
                                    model.game.table

                                _ ->
                                    Nothing
                        , addTo = Nothing
                        }
                , class "edLoginSocial edLoginSocial--reddit"
                ]
                [ img [ src "assets/social_icons/reddit.svg" ] []
                , text "Sign in with Reddit"
                ]
            ]
        , div [ class "edLoginDialog__register" ]
            [ div []
                [ text "... or just play for now:" ]
            , Html.form [ onSubmit <| Login model.loginName ]
                [ label []
                    [ text "Name"
                    , input
                        [ type_ "text"
                        , value model.loginName
                        , onInput SetLoginName
                        , class "edLoginDialog__name"
                        , dataTestId "login-input"
                        ]
                        []
                    ]
                ]
            ]
        , div [ class "edLoginDialog__buttons" ]
            [ button
                [ onClick <| ShowLogin LoginHide, dataTestId "login-close" ]
                [ text "Close" ]
            , button
                (List.append
                    (if model.loginName == "" then
                        [ disabled True ]

                     else
                        []
                    )
                    [ onClick <| Login model.loginName, dataTestId "login-login" ]
                )
                [ text "Play" ]
            ]
        ]
