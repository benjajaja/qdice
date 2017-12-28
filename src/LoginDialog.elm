module LoginDialog exposing (loginDialog, login)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Keyed
import Html.Events exposing (onSubmit)
import Http
import Material.Textfield as Textfield
import Material.Button as Button
import Material.Options as Options
import Types exposing (..)
import Backend.Decoding exposing (tokenDecoder)
import Backend.Encoding exposing (profileEncoder)


loginDialog : Model -> Html Msg
loginDialog model =
    (if model.showLoginDialog then
        div
            [ class "edLoginBackdrop" ]
            [ div
                [ class "edLoginDialog" ]
                [ body model ]
            ]
     else
        Html.text ""
    )


body model =
    div []
        [ div
            [ class "edLoginDialog__social" ]
            [ div []
                [ text "One-click sign-in:" ]
            , Button.render Mdl
                [ 12 ]
                model.mdl
                [ Options.onClick <| Authorize True
                , Button.raised
                , Button.colored
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
                [ Textfield.render Mdl
                    [ 13 ]
                    model.mdl
                    [ Textfield.label "Name"
                    , Textfield.floatingLabel
                    , Textfield.text_
                    , Textfield.value model.loginName
                    , Options.onInput SetLoginName
                    , Options.cs "edLoginDialog__name"
                    , Textfield.maxlength model.settings.maxNameLength
                    ]
                    []
                ]
            ]
        , div [ class "edLoginDialog__buttons" ]
            [ Button.render Mdl
                [ 11 ]
                model.mdl
                [ Options.onClick <| ShowLogin False ]
                [ text "Close" ]
            , Button.render Mdl
                [ 10 ]
                model.mdl
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
            }

        request =
            Http.request
                { method = "POST"
                , url = (model.backend.baseUrl ++ "/register")
                , headers = []
                , body =
                    (Http.jsonBody <| profileEncoder profile)
                , expect =
                    Http.expectJson <| tokenDecoder
                , timeout = Nothing
                , withCredentials = False
                }
    in
        { model | showLoginDialog = False }
            ! [ Http.send (Types.GetToken True) request
              ]
