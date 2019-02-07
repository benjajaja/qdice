module LoginDialog exposing (login, loginDialog)

import Backend.Decoding exposing (tokenDecoder)
import Backend.Encoding exposing (profileEncoder)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onClick, onInput, onSubmit)
import Html.Keyed
import Http
import Types exposing (..)


loginDialog : Model -> Html Msg
loginDialog model =
    case model.showLoginDialog of
        LoginHide ->
            text ""

        _ ->
            div
                [ class "edLoginBackdrop" ]
                [ div
                    [ class "edLoginDialog" ]
                    [ body model ]
                ]


body model =
    div []
        [ div
            [ class "edLoginDialog__social" ]
            [ div []
                [ text "One-click sign-in:" ]
            , button
                [ onClick <|
                    Authorize <|
                        case model.showLoginDialog of
                            LoginShowJoin ->
                                model.game.table

                            _ ->
                                Nothing
                , class "edLoginSocial edLoginSocial--google"
                ]
                [ img [ src "assets/social_icons/google.svg" ] []
                , text "Sign in with Google"
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
                        ]
                        []
                    ]
                ]
            ]
        , div [ class "edLoginDialog__buttons" ]
            [ button
                [ onClick <| ShowLogin LoginHide ]
                [ text "Close" ]
            , button
                (List.append
                    (if model.loginName == "" then
                        [ disabled True ]
                     else
                        []
                    )
                    [ onClick <| Login model.loginName ]
                )
                [ text "Play" ]
            ]
        ]


login : Model -> String -> ( Model, Cmd Msg )
login model name =
    let
        profile =
            { name = name
            , id = "💩"
            , email = Nothing
            , picture = ""
            , points = 0
            , level = 0
            }

        request =
            Http.request
                { method = "POST"
                , url = model.backend.baseUrl ++ "/register"
                , headers = []
                , body =
                    Http.jsonBody <| profileEncoder profile
                , expect =
                    Http.expectJson <| tokenDecoder
                , timeout = Nothing
                , withCredentials = False
                }
    in
        ( { model | showLoginDialog = LoginHide }
        , Http.send (Types.GetToken model.game.table) request
        )
