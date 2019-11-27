module MyProfile.MyProfile exposing (update, view)

import Backend.Decoding exposing (tokenDecoder)
import Backend.Encoding exposing (profileEncoder)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import MyProfile.Types exposing (..)
import Snackbar exposing (toastError)
import Types exposing (AuthNetwork(..), LoggedUser, Model, Msg(..), User(..))


view : MyProfileModel -> LoggedUser -> Html Msg
view model user =
    div [ class "edPage" ]
        [ div [ class "edPageSection" ]
            [ h2 [] [ text "My profile" ]
            , profileForm model user
            ]
        , div [ class "edPageSection" ]
            [ h2 [] [ text "Notifications" ]
            , p [] [ text "You can get a notification when it's your turn or the game starts." ]
            , button [ onClick RequestNotifications ] [ text "Enable notifications" ]
            , p []
                [ text "This feature is "
                , strong
                    []
                    [ text "not available on iOS. " ]
                , text "It exists since 2013 in Chrome and Firefox for Android."
                ]
            ]
        , div [ class "edPageSection" ]
            [ h2 [] [ text "Access" ]
            , h5 [] [ text "Connected login methods or networks:" ]
            , div [] <|
                List.map network user.networks

            -- , h5 [] [ text "Add login network to this account:" ]
            -- , div []
            -- [ button
            -- [ onClick <|
            -- Authorize
            -- { network = Google
            -- , table =
            -- Nothing
            -- , addTo = Just user.id
            -- }
            -- , class "edLoginSocial edLoginSocial--google"
            -- ]
            -- [ img [ src "assets/social_icons/google.svg" ] []
            -- , text "Connect with Google"
            -- ]
            -- , button
            -- [ onClick <|
            -- Authorize
            -- { network = Reddit
            -- , table =
            -- Nothing
            -- , addTo = Just user.id
            -- }
            -- , class "edLoginSocial edLoginSocial--reddit"
            -- ]
            -- [ img [ src "assets/social_icons/reddit.svg" ] []
            -- , text "Connect with Reddit"
            -- ]
            -- ]
            , h5 [] [ text "Log out now:" ]
            , button [ onClick Logout ] [ text "Logout" ]
            ]
        , div [ class "edPageSection" ]
            [ h5 [] [ text "Delete account:" ]
            , text "Not implemented yet, sorry!"
            ]
        ]


profileForm : MyProfileModel -> LoggedUser -> Html Msg
profileForm model user =
    Html.form [ onSubmit <| MyProfileMsg Save ]
        [ label [ class "edFormLabel" ]
            [ text "Player name"
            , input
                [ type_ "text"
                , value <| Maybe.withDefault user.name model.name
                , onInput <| MyProfileMsg << ChangeName
                ]
                []
            ]
        , label [ class "edFormLabel" ]
            [ text "Email"
            , input
                [ type_ "email"
                , value <| Maybe.withDefault (Maybe.withDefault "" user.email) model.email
                , onInput <| MyProfileMsg << ChangeEmail
                ]
                []
            ]
        , div []
            [ button
                []
                [ text "Save" ]
            ]
        , span [] [ text "Your email may be used to recover your access. You will not receive spam. If in the future we add some email features, they will be opt-in." ]
        ]


network : AuthNetwork -> Html Msg
network nw =
    div []
        [ text <|
            case nw of
                Password ->
                    "Password/None"

                Google ->
                    "Google"

                Telegram ->
                    "Telegram"

                Reddit ->
                    "Reddit"
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

        ChangeEmail value ->
            let
                p =
                    model.myProfile

                p_ =
                    { p | email = Just value }
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
                                    { user
                                        | name = Maybe.withDefault user.name model.myProfile.name
                                        , email =
                                            case model.myProfile.email of
                                                Just email ->
                                                    Just email

                                                Nothing ->
                                                    user.email
                                    }

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
