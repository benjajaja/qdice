module MyProfile.MyProfile exposing (view, update)

import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Material
import Material.Textfield as Textfield
import Material.Button as Button
import Material.Options as Options
import Types
import MyProfile.Types exposing (..)
import Backend.Decoding exposing (tokenDecoder)
import Backend.Encoding exposing (profileEncoder)
import Snackbar exposing (toastCmd)


view : Types.Model -> Types.LoggedUser -> Html.Html Types.Msg
view model user =
    div [ class "edMyProfile" ]
        [ (Textfield.render Mdl
            [ 0 ]
            model.mdl
            [ Textfield.label "Player name"
            , Textfield.floatingLabel
            , Textfield.text_
            , Textfield.value <| Maybe.withDefault user.name model.myProfile.name
            , Options.onInput ChangeName
            ]
            []
          )
        , Button.render Mdl
            [ 0 ]
            model.mdl
            [ Button.raised
            , Button.ripple
            , Options.onClick Save
            ]
            [ text "Save" ]
        ]
        |> Html.map Types.MyProfileMsg


update : Types.Model -> Msg -> ( Types.Model, Cmd Types.Msg )
update model msg =
    case msg of
        ChangeName value ->
            let
                p =
                    model.myProfile

                p_ =
                    { p | name = Just value }
            in
                { model | myProfile = p_ } ! []

        Save ->
            case model.backend.jwt of
                Nothing ->
                    model ! [ toastCmd "Missing JWT" ]

                Just jwt ->
                    case model.user of
                        Types.Logged user ->
                            let
                                profile =
                                    { user | name = Maybe.withDefault user.name model.myProfile.name }

                                request =
                                    Http.request
                                        { method = "PUT"
                                        , headers = [ Http.header "authorization" ("Bearer " ++ jwt) ]
                                        , url = (model.backend.baseUrl ++ "/profile")
                                        , body =
                                            (Http.jsonBody <| profileEncoder profile)
                                        , expect =
                                            Http.expectJson <| tokenDecoder
                                        , timeout = Nothing
                                        , withCredentials = False
                                        }
                            in
                                model ! [ Http.send (Types.GetToken False) request ]

                        Types.Anonymous ->
                            Debug.crash "cannot modify anonymous user"

        Mdl msg ->
            let
                ( m, cmd ) =
                    Material.update MyProfile.Types.Mdl msg model
            in
                m ! [ Cmd.map Types.MyProfileMsg cmd ]
