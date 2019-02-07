module MyProfile.MyProfile exposing (update, view)

import Backend.Decoding exposing (tokenDecoder)
import Backend.Encoding exposing (profileEncoder)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import MyProfile.Types exposing (..)
import Snackbar exposing (toast)
import Types


view : Types.Model -> Types.LoggedUser -> Html.Html Types.Msg
view model user =
    div [ class "edMyProfile" ]
        [ label []
            [ text "Player name"
            , input
                [ type_ "text"
                , value <| Maybe.withDefault user.name model.myProfile.name
                , onInput <| Types.MyProfileMsg << ChangeName
                ]
                []
            ]
        , button
            [ onClick <| Types.MyProfileMsg Save
            ]
            [ text "Save" ]
        ]


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
                ( { model | myProfile = p_ }
                , Cmd.none
                )

        Save ->
            case model.backend.jwt of
                Nothing ->
                    toast model "Missing JWT" "jwt is Nothing, cannot update profile"

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
                                , Http.send (Types.GetToken Nothing) request
                                )

                        Types.Anonymous ->
                            toast model "cannot modify anonymous user" "UI allowed to modify anonymous user!"
