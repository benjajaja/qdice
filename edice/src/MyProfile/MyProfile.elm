module MyProfile.MyProfile exposing (addNetworks, init, update, view)

import Backend.Encoding exposing (encodeAuthNetwork)
import Backend.HttpCommands
import Cropper
import File
import File.Select as Select
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Icon
import MyOauth exposing (saveToken)
import MyProfile.Types exposing (..)
import Routing exposing (navigateTo)
import Routing.String exposing (linkAttr)
import Snackbar exposing (toastError)
import Task
import Types exposing (AuthNetwork(..), LoggedUser, Model, Msg(..), PushEvent(..), Route(..), User(..))
import Backend.Encoding exposing (encodeAuthNetwork)


init : MyProfileModel
init =
    { name = Nothing
    , email = Nothing
    , password = Nothing
    , passwordCheck = Nothing
    , addingPassword = False
    , picture = Nothing
    , cropper =
        Cropper.init
            { url = ""
            , crop = { width = 100, height = 100 }
            }
    , deleteAccount = MyProfile.Types.None
    , saving = False
    }


view : MyProfileModel -> Bool -> LoggedUser -> Types.Preferences -> Types.SessionPreferences -> Html Msg
view model isSteam user preferences sessionPreferences =
    div [ class "edPage" ]
        [ div [ class "edPageSection" ]
            [ h2 [] [ text "My Account" ]
            , p []
                [ a [ linkAttr <| ProfileRoute user.id user.name ] [ text "Go to my public profile as seen by others" ]
                ]
            , profileForm model user
            ]
        , if isSteam then
            text ""
          else
            div [ class "edPageSection" ] <|
                h2 [] [ text "Notifications" ]
                    :: notifications model user preferences sessionPreferences
                    ++ [ p []
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
            , div [] <|
                case user.networks of
                    [] ->
                        [ h2 [ style "color" "red" ] [ text "Warning!" ]
                        , p [] [ text "You will not be able to access this account on another device, ever, until you add a login network." ]
                        , p [] [ text "The same way, if you clear this browser's history/cookies/data, you won't be able to recover this user." ]
                        ]

                    _ ->
                        []
            , h5 [] [ text "Add a login network to this account:" ]
            , div [] <|
                addNetworks
                    model
                    user
            ]
        , div [ class "edPageSection" ] <|
            h2 [] [ text "Danger zone" ]
            
                :: (case user.networks of
                        [] ->
                            [ h5 [] [ text "Log out now:" ]
                            , p [] [ text "If you don't have any login method or network, then you can never recover this account!" ]
                            ]

                        _ ->
                            []
                   )
                ++ [ button [ onClick Logout ] [ text "Logout" ]
                   , h5 [] [ text "Delete account:" ]
                   ]
                ++ deleteAccount model
        ]


notifications : MyProfileModel -> LoggedUser -> Types.Preferences -> Types.SessionPreferences -> List (Html Msg)
notifications _ _ preferences sessionPreferences =
    if not sessionPreferences.notificationsEnabled then
        [ div [] [ text "You can enable some notifications like when it's your turn, or when the game starts:" ]
        , div [] [ button [ onClick RequestNotifications ] [ text "Enable notifications" ] ]
        ]

    else
        [ div [] [ text "You have notifications enabled on this device/browser." ]
        , div [] [ text "You will get a notification when the tab is in background and it's your turn." ]
        , div [] [ button [ onClick RenounceNotifications ] [ text "Disable notifications" ] ]
        , div [] [ text "You can also receive a push notification even if you're not in any game and don't even have the website opened." ]
        , div [] [ text "Get a notification when:" ]
        , div []
            [ label
                [ class "edCheckbox--checkbox"
                , onClick <|
                    PushRegisterEvent ( Turn, not <| List.member Turn preferences.pushEvents )
                ]
                [ Icon.icon <|
                    if List.member Turn <| preferences.pushEvents then
                        "check_box"

                    else
                        "check_box_outline_blank"
                , text "it's my turn"
                ]
            ]

        , div []
            [ label
                [ class "edCheckbox--checkbox"
                , onClick <|
                PushRegisterEvent ( GameStart, not <| List.member GameStart preferences.pushEvents )
                ]
                [ Icon.icon <|
                    if List.member GameStart preferences.pushEvents then
                    "check_box"

                    else
                    "check_box_outline_blank"
                , text "any game countdown starts"
                ]
            ]
        , div []
            [ label
                [ class "edCheckbox--checkbox"
                , onClick <|
                    PushRegisterEvent ( PlayerJoin, not <| List.member PlayerJoin preferences.pushEvents )
                ]
                [ Icon.icon <|
                    if List.member PlayerJoin preferences.pushEvents then
                        "check_box"

                    else
                        "check_box_outline_blank"
                , text "anybody joins any table"
                ]
            ]
        ]


availableNetworks : LoggedUser -> List AuthNetwork
availableNetworks user =
    List.filter (\i -> not <| List.member i user.networks) [ Password ]
    --[ Google, Github, Reddit, Password ]


addNetworks : MyProfileModel -> LoggedUser -> List (Html Msg)
addNetworks model user =
    case availableNetworks user of
        [] ->
            [ text "Already connected to all possible auth networks. Congratulations!" ]

        available ->
            List.map
                (\n ->
                    case n of
                        Password ->
                            div
                                [ class "edLoginSocial edLoginSocial--password"
                                ]
                                [ div [ class "edLoginSocial--password__label" ]
                                    [ text "Email:" ]
                                , div [ class "edLoginSocial--password__input" ]
                                    [ input [ type_ "email", placeholder "email@address.com", onInput <| MyProfileMsg << ChangeEmail ] []
                                    ]
                                , div [ class "edLoginSocial--password__placeholder" ] []
                                , div [ class "edLoginSocial--password__label" ]
                                    [ text "Password:" ]
                                , div [ class "edLoginSocial--password__input" ]
                                    [ input [ type_ "password", placeholder "********", onInput <| MyProfileMsg << ChangePassword ] []
                                    ]
                                , div [ class "edLoginSocial--password__button" ]
                                    [ button
                                        (case model.password of
                                            Nothing ->
                                                [ disabled True ]

                                            Just p ->
                                                case model.email of
                                                    Nothing ->
                                                        [ disabled True ]

                                                    Just e ->
                                                      if model.addingPassword then
                                                        [ disabled True ]
                                                      else
                                                        [ onClick <| SetPassword ( e, p ) Nothing ]
                                        )
                                        [ text "Set login" ]
                                    ]
                                ]

                        _ ->
                            button
                                [ onClick <|
                                    Authorize
                                        { network = n
                                        , table =
                                            Nothing
                                        , addTo = Just user.id
                                        }
                                , class <| "edLoginSocial edLoginSocial--" ++ encodeAuthNetwork n
                                ]
                                [ img [ src <| "assets/social_icons/" ++ encodeAuthNetwork n ++ ".svg" ] []
                                , text <| "Connect with " ++ encodeAuthNetwork n
                                ]
                )
                available
                |> List.foldl
                    (\element list ->
                        case list of
                            [] ->
                                [ element ]

                            _ ->
                                list
                                    ++ [ div [ class "edLoginSocial__or" ]
                                            [ span [ class "edLoginSocial__or__line" ] []
                                            , span [] [ text " OR " ]
                                            , span [ class "edLoginSocial__or__line" ] []
                                            ]
                                       , element
                                       ]
                    )
                    []


profileForm : MyProfileModel -> LoggedUser -> Html Msg
profileForm model user =
    Html.form [ onSubmit <| MyProfileMsg Save ] <|
        [ label [ class "edFormLabel" ]
            [ text "Player name"
            , input
                [ type_ "text"
                , value <| Maybe.withDefault user.name model.name
                , onInput <| MyProfileMsg << ChangeName
                ]
                []
            ]
        , avatarUpload model user
        , p [] []
        ]
            ++ (if List.member Password user.networks then
                    [ label [ class "edFormLabel" ]
                        [ text "Email"
                        , input
                            [ type_ "email"
                            , value <| Maybe.withDefault (Maybe.withDefault "" user.email) model.email
                            , placeholder "email@address.com"
                            , onInput <| MyProfileMsg << ChangeEmail
                            ]
                            []
                        , text "Current password (for security)"
                        , input
                            [ type_ "password"
                            , placeholder ""
                            , value <| Maybe.withDefault "" model.passwordCheck
                            , onInput <| MyProfileMsg << ChangePasswordCheck
                            ]
                            []
                        , text "New password"
                        , input
                            [ type_ "password"
                            , placeholder "Leave unchanged"
                            , value <| Maybe.withDefault "" model.password
                            , onInput <| MyProfileMsg << ChangePassword
                            ]
                            []
                        ]
                    ]

                else
                    []
               )
            ++ [ div []
                    [ if model.saving then
                        button [ disabled True ] [ text "Saving..." ]

                      else
                        button
                            (if List.member Password user.networks && model.password /= Nothing && model.passwordCheck == Nothing then
                                [ disabled True ]

                             else
                                []
                            )
                            [ text "Save changes"
                            ]
                    ]
               ]


avatarUpload : MyProfileModel -> LoggedUser -> Html Msg
avatarUpload model user =
    div []
        [ label [ class "edFormLabel" ]
            [ text "Current avatar"
            ]
        , div [] <|
            case model.picture of
                Just _ ->
                    [ div [ class "edAvatarCropper" ]
                        [ Cropper.view model.cropper |> Html.map (ToCropper >> MyProfileMsg)
                        ]
                    , div [] [ text "Drag to center, use handle to zoom:" ]
                    , p []
                        [ input
                            [ onInput <| Zoom >> MyProfileMsg
                            , type_ "range"
                            , class "edButton"
                            , Html.Attributes.min "0"
                            , Html.Attributes.max "1"
                            , Html.Attributes.step "0.0001"
                            , value (String.fromFloat model.cropper.zoom)
                            ]
                            []
                        ]
                    , button
                        [ type_ "button", onClick <| MyProfileMsg AvatarReset ]
                        [ text "Reset picture" ]
                    ]

                Nothing ->
                    [ div [ class "edAvatarPreview" ]
                        [ img [ src user.picture ] [] ]
                    , button
                        [ type_ "button", onClick <| MyProfileMsg AvatarRequested ]
                        [ text "Chose new picture..." ]
                    ]
        ]


networkDisplay : AuthNetwork -> String
networkDisplay nw =
    case nw of
        Password ->
            "Password"

        Github ->
            "GitHub"

        Google ->
            "Google"

        Telegram ->
            "Telegram"

        Steam ->
            "Steam"

        Reddit ->
            "Reddit"


deleteAccount : MyProfileModel -> List (Html Msg)
deleteAccount model =
    case model.deleteAccount of
        MyProfile.Types.None ->
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

        ChangePassword value ->
            let
                p =
                    model.myProfile

                p_ =
                    { p
                        | password =
                            case value of
                                "" ->
                                    Nothing

                                _ ->
                                    Just value
                    }
            in
            ( { model | myProfile = p_ }
            , Cmd.none
            )

        ChangePasswordCheck value ->
            let
                p =
                    model.myProfile

                p_ =
                    { p
                        | passwordCheck =
                            case value of
                                "" ->
                                    Nothing

                                _ ->
                                    Just value
                    }
            in
            ( { model | myProfile = p_ }
            , Cmd.none
            )

        Save ->
            case model.user of
                Logged user ->
                    let
                        profileUpdate : MyProfileUpdate
                        profileUpdate =
                            { name = model.myProfile.name
                            , email =
                                if List.member Password user.networks then
                                    model.myProfile.email

                                else
                                    Nothing
                            , picture =
                                Maybe.map
                                    (always <|
                                        Cropper.cropData
                                            model.myProfile.cropper
                                    )
                                    model.myProfile.picture
                            , password =
                                if List.member Password user.networks then
                                    model.myProfile.password

                                else
                                    Nothing
                            , passwordCheck =
                                if List.member Password user.networks then
                                    model.myProfile.passwordCheck

                                else
                                    Nothing
                            }

                        p =
                            model.myProfile

                        p_ =
                            { p
                                | saving =
                                    not <|
                                        List.all ((==) Nothing)
                                            [ model.myProfile.name
                                            , model.myProfile.email
                                            , model.myProfile.picture
                                            , model.myProfile.password
                                            , model.myProfile.passwordCheck
                                            ]
                            }
                    in
                    ( { model | myProfile = p_ }
                    , if
                        List.all ((==) Nothing)
                            [ model.myProfile.name
                            , model.myProfile.email
                            , model.myProfile.picture
                            , model.myProfile.password
                            , model.myProfile.passwordCheck
                            ]
                      then
                        Cmd.none

                      else
                        Backend.HttpCommands.updateAccount model.backend profileUpdate
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
                MyProfile.Types.None ->
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
                                [ Snackbar.toastMessage "Account deleted" <| Just 5000
                                , navigateTo model.zip model.key HomeRoute
                                , saveToken Nothing
                                ]
                            )

                        Err err ->
                            ( model_
                            , Backend.HttpCommands.toastHttpError err
                            )

        AvatarRequested ->
            ( model, Select.file [ "image/*" ] (AvatarSelected >> MyProfileMsg) )

        AvatarSelected file ->
            ( model
            , Task.perform
                (AvatarLoaded
                    >> MyProfileMsg
                )
              <|
                File.toUrl file
            )

        AvatarLoaded url ->
            let
                p =
                    model.myProfile

                p_ =
                    { p
                        | picture = Just url
                        , cropper =
                            Cropper.zoom
                                (Cropper.init
                                    { url = url
                                    , crop = { width = 100, height = 100 }
                                    }
                                )
                                0
                    }
            in
            ( { model | myProfile = p_ }, Cmd.none )

        AvatarReset ->
            let
                p =
                    model.myProfile
            in
            ( { model | myProfile = { p | picture = Nothing } }, Cmd.none )

        ToCropper subMsg ->
            let
                p =
                    model.myProfile

                ( updatedSubModel, subCmd ) =
                    Cropper.update subMsg p.cropper

                p_ =
                    { p | cropper = updatedSubModel }
            in
            ( { model | myProfile = p_ }, Cmd.map (ToCropper >> MyProfileMsg) subCmd )

        Zoom zoom ->
            let
                p =
                    model.myProfile

                p_ =
                    { p | cropper = Cropper.zoom p.cropper (Maybe.withDefault 0 (String.toFloat zoom)) }
            in
            ( { model | myProfile = p_ }, Cmd.none )
