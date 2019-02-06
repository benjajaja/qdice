module LoginDialog exposing (login, loginDialog)

import Backend.Decoding exposing (tokenDecoder)
import Backend.Encoding exposing (profileEncoder)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (onSubmit)
import Html.Keyed
import Http
import Material.Button as Button
import Material.Options as Options
import Material.Textfield as Textfield
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
            , Button.view Mdl
                "button-login-social"
                model.mdc
                [ Options.onClick <|
                    Authorize <|
                        case model.showLoginDialog of
                            LoginShowJoin ->
                                model.game.table

                            _ ->
                                Nothing
                , Button.raised
                  --, Button.colored
                , Button.ripple
                , Options.cs "edLoginSocial edLoginSocial--google"
                ]
                [ img [ src "assets/social_icons/google.svg" ] []
                , text "Sign in with Google"
                ]
            ]
        , div [ class "edLoginDialog__register" ]
            [ div []
                [ text "... or just play for now:" ]
            , Html.form [ onSubmit <| Login model.loginName ]
                [ Textfield.view Mdl
                    "input-login-name"
                    model.mdc
                    [ Textfield.label "Name"
                      --, Textfield.floatingLabel
                    , Textfield.type_ "text"
                    , Textfield.value model.loginName
                    , Options.onInput SetLoginName
                    , Options.cs "edLoginDialog__name"
                      --, Textfield.maxlength model.settings.maxNameLength
                    ]
                    []
                ]
            ]
        , div [ class "edLoginDialog__buttons" ]
            [ Button.view Mdl
                "button-login-close"
                model.mdc
                [ Options.onClick <| ShowLogin LoginHide ]
                [ text "Close" ]
            , Button.view Mdl
                "button-login"
                model.mdc
                (List.append
                    (if model.loginName == "" then
                        [ Button.disabled ]
                     else
                        []
                    )
                    [ Options.onClick <| Login model.loginName ]
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
