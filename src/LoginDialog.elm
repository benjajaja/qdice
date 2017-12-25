module LoginDialog exposing (loginDialog, login)

import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Material.Dialog as Dialog
import Material.Textfield as Textfield
import Material.Button as Button
import Material.Options as Options
import Types exposing (..)
import Backend.Decoding exposing (tokenDecoder)
import Backend.Encoding exposing (profileEncoder)


loginDialog : Model -> Html Msg
loginDialog model =
    Dialog.view
        []
        --[ Dialog.title [] [ text "Start playing!" ]
        [ Dialog.content []
            [ Button.render Mdl
                [ 1 ]
                model.mdl
                [ Dialog.closeOn "click"
                , Options.onClick Authorize
                , Button.raised
                , Button.colored
                , Button.ripple
                ]
                [ img [ src "assets/social_icons/google.svg" ] []
                , text "Sign in with Google"
                ]
            , p []
                [ text "... or just play with keeping points:" ]
            , Textfield.render Mdl
                [ 3 ]
                model.mdl
                [ Textfield.label "Name"
                , Textfield.floatingLabel
                , Textfield.text_
                , Textfield.value model.loginName
                , Options.onInput SetLoginName
                ]
                []
            ]
        , Dialog.actions []
            [ Button.render Mdl
                [ 0 ]
                model.mdl
                (List.append
                    (if model.loginName == "" then
                        [ Button.disabled ]
                     else
                        [ Dialog.closeOn "click" ]
                    )
                    [ Options.onClick <| Login model.loginName ]
                )
                [ text "Play" ]
            , Button.render Mdl
                [ 1 ]
                model.mdl
                [ Dialog.closeOn "click" ]
                [ text "Close" ]
            ]
        ]


login : Model -> String -> ( Model, Cmd Msg )
login model name =
    let
        profile =
            { name = name
            , id = "💩"
            , email = ""
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
        model ! [ Http.send (Types.GetToken) request ]
