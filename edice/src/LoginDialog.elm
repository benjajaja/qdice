module LoginDialog exposing (body)

import Animation
import Helpers exposing (dataTestId)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import Icon
import Tables exposing (Table)
import Types exposing (AuthNetwork(..), LoginDialogStatus(..), LoginPasswordStep(..), Model, Msg(..))


body : Model -> Maybe Table -> Html Msg
body model joinTable =
    div [ dataTestId "login-dialog" ]
        [ div
            [ class "edLoginDialog__social" ]
            [ div []
                [ text "One-click sign-in:" ]
            , button
                [ onClick <|
                    Authorize
                        { network = Google
                        , table = joinTable
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
                        { network = Github
                        , table = joinTable
                        , addTo = Nothing
                        }
                , class "edLoginSocial edLoginSocial--github"
                ]
                [ img [ src "assets/social_icons/github.svg" ] []
                , text "Sign in with GitHub"
                ]
            , button
                [ onClick <|
                    Authorize
                        { network = Reddit
                        , table = joinTable
                        , addTo = Nothing
                        }
                , class "edLoginSocial edLoginSocial--reddit"
                ]
                [ img [ src "assets/social_icons/reddit.svg" ] []
                , text "Sign in with Reddit"
                ]
            , div []
                [ text "Email / Password:" ]
            , Html.form [ class "edLoginPassword", onSubmit <| SetLoginPassword <| StepNext 1 joinTable ]
                [ div
                    ([ class "edLoginPassword_input" ]
                        ++ (Animation.render <|
                                Tuple.first model.loginPassword.animations
                           )
                    )
                    [ input
                        [ type_ "email"
                        , id "login-dialog-email"
                        , placeholder "you@mail.com"
                        , value model.loginPassword.email
                        , onInput <| SetLoginPassword << StepEmail
                        ]
                        []
                    , button [ class "edLoginPassword_btn", type_ "button", onClick <| SetLoginPassword <| StepNext 1 Nothing ] [ Icon.icon "keyboard_tab" ]
                    ]
                , div
                    ([ class "edLoginPassword_input edLoginPassword_input-last" ]
                        ++ (Animation.render <|
                                Tuple.second model.loginPassword.animations
                           )
                    )
                    [ button [ class "edLoginPassword_btn", type_ "button", onClick <| SetLoginPassword <| StepNext 0 Nothing ] [ Icon.icon "keyboard_backspace" ]
                    , input
                        [ type_ "password"
                        , id "login-dialog-password"
                        , placeholder "********"
                        , value model.loginPassword.password
                        , onInput <| SetLoginPassword << StepPassword
                        ]
                        []
                    , button [ class "edLoginPassword_btn" ] [ Icon.icon "keyboard_return" ]
                    ]
                ]
            ]
        , div [ class "edLoginDialog__register" ]
            [ div []
                [ text "... or just play for now:" ]
            , Html.form [ onSubmit <| Register model.loginName joinTable ]
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
                    [ onClick <| Register model.loginName joinTable, dataTestId "login-login" ]
                )
                [ text "Play" ]
            ]
        ]
