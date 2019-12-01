module MyProfile.MyProfile exposing (update, view)

import Backend.Decoding exposing (tokenDecoder)
import Backend.Encoding exposing (profileEncoder)
import Backend.HttpCommands
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import MyOauth exposing (saveToken)
import MyProfile.Types exposing (..)
import Routing exposing (navigateTo)
import Snackbar exposing (toastError)
import Types exposing (AuthNetwork(..), LoggedUser, Model, Msg(..), Route(..), User(..))


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
                List.map (\n -> div [] [ text <| networkDisplay n ]) user.networks
            , h5 [] [ text "Add login network to this account:" ]
            , div [] <|
                addNetworks
                    user
            , h5 [] [ text "Log out now:" ]
            , button [ onClick Logout ] [ text "Logout" ]
            ]
        , div [ class "edPageSection" ]
            (h5
                []
                [ text "Delete account:" ]
                :: deleteAccount model
            )
        ]


availableNetworks : LoggedUser -> List AuthNetwork
availableNetworks user =
    List.filter (\i -> not <| List.member i user.networks) [ Google, Reddit ]


addNetworks : LoggedUser -> List (Html Msg)
addNetworks user =
    case availableNetworks user of
        [] ->
            [ text "Already connected to all." ]

        available ->
            List.map
                (\n ->
                    button
                        [ onClick <|
                            Authorize
                                { network = n
                                , table =
                                    Nothing
                                , addTo = Just user.id
                                }
                        , class <| "edLoginSocial edLoginSocial--" ++ networkIdName n
                        ]
                        [ img [ src <| "assets/social_icons/" ++ networkIdName n ++ ".svg" ] []
                        , text <| "Connect with " ++ networkIdName n
                        ]
                )
                available


networkIdName : AuthNetwork -> String
networkIdName network =
    case network of
        Google ->
            "google"

        Reddit ->
            "reddit"

        Telegram ->
            "telegram"

        Password ->
            "password"


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


networkDisplay : AuthNetwork -> String
networkDisplay nw =
    case nw of
        Password ->
            "None"

        Google ->
            "Google"

        Telegram ->
            "Telegram"

        Reddit ->
            "Reddit"


deleteAccount : MyProfileModel -> List (Html Msg)
deleteAccount model =
    case model.deleteAccount of
        None ->
            [ button [ onClick <| MyProfileMsg <| DeleteAccount Confirm ]
                [ text "Delete my account" ]
            ]

        Confirm ->
            [ button [ onClick <| MyProfileMsg <| DeleteAccount Process ]
                [ text
                    "Confirm: delete my account (irreversible)"
                ]
            ]

        Process ->
            [ text "Deleting..." ]

        Deleted res ->
            case res of
                Err _ ->
                    [ text "Could not delete account. Try reloading." ]

                Ok _ ->
                    [ text "Account deleted." ]


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
                    in
                    ( model
                    , Backend.HttpCommands.updateAccount model.backend profile
                    )

                Anonymous ->
                    ( model, toastError "cannot modify anonymous user" "UI allowed to modify anonymous user!" )

        DeleteAccount state ->
            let
                profile =
                    model.myProfile

                model_ =
                    { model
                        | myProfile =
                            { profile | deleteAccount = state }
                    }
            in
            case state of
                None ->
                    ( model_, Cmd.none )

                Confirm ->
                    ( model_, Cmd.none )

                Process ->
                    ( model_
                    , Backend.HttpCommands.deleteAccount (\a -> MyProfileMsg <| DeleteAccount <| Deleted a) model.backend model.user
                    )

                Deleted res ->
                    case res of
                        Ok _ ->
                            let
                                backend =
                                    model.backend

                                backend_ =
                                    { backend | jwt = Nothing }
                            in
                            ( { model | user = Anonymous, backend = backend_ }
                            , Cmd.batch
                                [ Snackbar.toastMessage "Account deleted" 0
                                , navigateTo model.key HomeRoute
                                , saveToken Nothing
                                ]
                            )

                        Err err ->
                            ( model_
                            , Backend.HttpCommands.toastHttpError err
                            )
