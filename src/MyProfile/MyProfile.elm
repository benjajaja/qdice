module MyProfile.MyProfile exposing (update, view)

import Backend.Decoding exposing (tokenDecoder)
import Backend.Encoding exposing (profileEncoder)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import MyProfile.Types exposing (..)
import Snackbar exposing (toastError)
import Types exposing (Model, Msg(..), User(..), LoggedUser)


view : MyProfileModel -> LoggedUser -> Html Msg
view model user =
    div [ class "edMyProfile" ]
        [ h1 [] [ text "My profile" ]
        , profileForm model user
        , h1 [] [ text "Access" ]
        , button [ onClick Logout ] [ text "Logout" ]
        ]


profileForm : MyProfileModel -> LoggedUser -> Html Msg
profileForm model user =
    Html.form []
        [ label [ class "edFormLabel" ]
            [ text "Player name"
            , input
                [ type_ "text"
                , value <| Maybe.withDefault user.name model.name
                , onInput <| MyProfileMsg << ChangeName
                ]
                []
            ]
        , button
            [ onClick <| MyProfileMsg Save
            ]
            [ text "Save" ]
        ]


update : Model -> MyProfileMsg -> ( Model, Cmd Msg )
update model msg =
    case msg of
        ChangeName value ->
            let
                p =
                    model.myProfile

                p_ =
                    { p | name = Just value }
            in
                ( { model | myProfile = p_ }
                , Cmd.none
                )

        Save ->
            case model.backend.jwt of
                Nothing ->
                    ( model, toastError "Missing JWT" "jwt is Nothing, cannot update profile" )

                Just jwt ->
                    case model.user of
                        Logged user ->
                            let
                                profile =
                                    { user | name = Maybe.withDefault user.name model.myProfile.name }

                                request =
                                    Http.request
                                        { method = "PUT"
                                        , headers = [ Http.header "authorization" ("Bearer " ++ jwt) ]
                                        , url = model.backend.baseUrl ++ "/profile"
                                        , body =
                                            Http.jsonBody <| profileEncoder profile
                                        , expect =
                                            Http.expectJson <| tokenDecoder
                                        , timeout = Nothing
                                        , withCredentials = False
                                        }
                            in
                                ( model
                                , Http.send (GetToken Nothing) request
                                )

                        Anonymous ->
                            ( model, toastError "cannot modify anonymous user" "UI allowed to modify anonymous user!" )
