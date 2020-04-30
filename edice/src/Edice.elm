port module Edice exposing (init, pushSubscribe, started, subscriptions, updateWrapper, view)

import Animation
import Array
import Backend
import Backend.HttpCommands exposing (getPushKey, loadGlobalSettings, loadMe, login, register, registerPush, registerPushEvent)
import Backend.MqttCommands exposing (sendGameCommand)
import Backend.Types exposing (ConnectionStatus(..), TableMessage(..), TopicDirection(..))
import Board
import Board.Types
import Browser
import Browser.Dom
import Browser.Events
import Browser.Navigation exposing (Key)
import Comments
import Dialog exposing (dialog)
import Dict
import Footer exposing (footer)
import GA exposing (ga)
import Game.State exposing (gameCommand)
import Game.Types exposing (PlayerAction(..))
import Game.View
import Games
import Games.Replayer
import Helpers exposing (httpErrorToString, is502, pipeUpdates)
import Html
import Html.Attributes
import Http exposing (Error(..))
import LeaderBoard.State
import LeaderBoard.View
import MyOauth
import MyProfile.MyProfile
import MyProfile.Types
import Placeholder
import Profile
import Routing exposing (navigateTo, parseLocation)
import Snackbar exposing (toastError, toastMessage)
import Static.View
import Tables exposing (Map(..), Table)
import Task
import Time
import Types exposing (..)
import Url exposing (Url)


init : Flags -> Url -> Key -> ( Model, Cmd Msg )
init flags location key =
    let
        route =
            Routing.parseLocation location

        table =
            tableFromRoute route

        ( game, gameCmd ) =
            Game.State.init table Nothing

        ( backend, backendCmd ) =
            Backend.init flags.version location flags.token flags.isTelegram

        ( backend_, routeCmds ) =
            case route of
                TokenRoute token ->
                    let
                        loadBackend =
                            { backend | jwt = Just token }
                    in
                    ( loadBackend
                    , [ MyOauth.saveToken <| Just token
                      , loadMe loadBackend
                      , navigateTo flags.zip key <| GameRoute ""
                      ]
                    )

                _ ->
                    ( backend
                    , [ Cmd.none ]
                    )

        ( oauth, oauthCmds ) =
            MyOauth.init key location backend_

        model : Model
        model =
            { route = route
            , key = key
            , oauth = oauth
            , game = game
            , myProfile = { name = Nothing, email = Nothing, password = Nothing, passwordCheck = Nothing, picture = Nothing, deleteAccount = MyProfile.Types.None }
            , backend = backend_
            , user = Types.Anonymous
            , tableList = []
            , time = Time.millisToPosix 0
            , zone = Time.utc
            , isTelegram = flags.isTelegram
            , screenshot = flags.screenshot
            , zip = flags.zip
            , loginName = ""
            , loginPassword =
                { step = 0
                , email = ""
                , password = ""
                , animations =
                    ( Animation.style [ Animation.left <| Animation.percent 0 ]
                    , Animation.style [ Animation.left <| Animation.percent 100 ]
                    )
                }
            , dialog = Hide
            , settings =
                { gameCountdownSeconds = 30
                , maxNameLength = 20
                , turnSeconds = 10
                }
            , preferences =
                { pushEvents = []
                }
            , sessionPreferences =
                { notificationsEnabled = flags.notificationsEnabled
                , muted = flags.muted
                }
            , leaderBoard =
                { loading = False
                , month = "this month"
                , top = []
                , board = []
                , page = 1
                }
            , otherProfile =
                Profile.init
            , games =
                { tables = Dict.empty
                , all = []
                , fetching = Nothing
                }
            , fullscreen = False
            , comments = Comments.init
            , replayer = Nothing
            }

        ( model_, routeCmd ) =
            Routing.routeEnterCmd model route

        cmds =
            Cmd.batch <|
                List.concat
                    [ routeCmds -- token
                    , [ started "peekaboo"
                      , backendCmd
                      ]
                    , oauthCmds
                    , [ loadGlobalSettings backend ]
                    , [ routeCmd ]
                    , [ Task.perform UserZone Time.here ]
                    , [ gameCmd ]
                    , [ Task.perform (\v -> Resized (round v.viewport.width) (round v.viewport.height)) Browser.Dom.getViewport ]
                    ]
    in
    ( model_, cmds )


updateWrapper : Msg -> Model -> ( Model, Cmd Msg )
updateWrapper msg model =
    let
        ( model_, cmd ) =
            update msg model
    in
    ( model_, cmd )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Nop ->
            ( model
            , Cmd.none
            )

        MyProfileMsg myProfileMsg ->
            MyProfile.MyProfile.update model myProfileMsg

        LeaderboardMsg lMsg ->
            LeaderBoard.State.update model lMsg

        GamesMsg aMsg ->
            Games.update model aMsg

        GetGlobalSettings res ->
            case res of
                Err err ->
                    if is502 err then
                        ( model, toastError "Server down, please retry" <| httpErrorToString err )

                    else
                        ( model, toastError "Could not load global configuration!" <| httpErrorToString err )

                Ok { settings, tables, leaderBoard, version } ->
                    let
                        ( month, top ) =
                            leaderBoard

                        model_ =
                            { model
                                | settings = settings
                                , tableList = tables
                                , leaderBoard =
                                    { loading = model.leaderBoard.loading
                                    , month = month
                                    , top = top
                                    , board = model.leaderBoard.board
                                    , page = model.leaderBoard.page
                                    }
                            }

                        ( modelWithTable, cmd ) =
                            case model.route of
                                GameRoute table ->
                                    case model.backend.status of
                                        Online ->
                                            Game.State.changeTable model_ table

                                        _ ->
                                            Game.State.changeTable model_ table

                                HomeRoute ->
                                    case model_.backend.jwt of
                                        Nothing ->
                                            ( model_, Routing.goToBestTable model_ Nothing True )

                                        Just _ ->
                                            ( model_, Cmd.none )

                                _ ->
                                    ( model_, Cmd.none )
                    in
                    ( modelWithTable
                    , if
                        String.length version
                            > 0
                            && String.length model.backend.version
                            > 0
                            && model.backend.version
                            /= "dev"
                            && version
                            /= "dev"
                            && version
                            /= model.backend.version
                      then
                        Cmd.batch
                            [ cmd
                            , toastMessage "Page has outdated version, please refresh the page or go to qdice.wtf" <| Just 10000
                            ]

                      else
                        cmd
                    )

        GetToken joinTable res ->
            case res of
                Err err ->
                    ( model
                    , toastError ("Could not load profile: " ++ httpErrorToString err) <| httpErrorToString err
                    )

                Ok token ->
                    let
                        backend =
                            model.backend

                        backend_ =
                            { backend | jwt = Just token }

                        needsTable : Maybe Table
                        needsTable =
                            case model.game.table of
                                Just currentTable ->
                                    joinTable
                                        |> Maybe.andThen
                                            (\t ->
                                                if t /= currentTable then
                                                    Just t

                                                else
                                                    Nothing
                                            )

                                Nothing ->
                                    Nothing

                        model_ =
                            { model | backend = backend_ }

                        cmd =
                            Cmd.batch <|
                                List.append
                                    [ MyOauth.saveToken <| Just token
                                    , loadMe backend_
                                    ]
                                <|
                                    case joinTable of
                                        Just table ->
                                            [ sendGameCommand model_.backend (Just table) Game.Types.Join ]

                                        Nothing ->
                                            []
                    in
                    case needsTable of
                        Nothing ->
                            ( model_, cmd )

                        Just table ->
                            pipeUpdates Game.State.changeTable table ( model_, cmd )

        GetUpdateProfile res ->
            case res of
                Err err ->
                    ( model
                    , toastError err err
                    )

                Ok token ->
                    let
                        backend =
                            model.backend

                        backend_ =
                            { backend | jwt = Just token }

                        model_ =
                            { model | backend = backend_ }
                    in
                    ( model_
                    , Cmd.batch
                        [ MyOauth.saveToken <| Just token
                        , loadMe backend_
                        , toastMessage "Profile updated." Nothing
                        ]
                    )

        GetProfile res ->
            case res of
                Err err ->
                    let
                        backend =
                            model.backend
                    in
                    ( { model | user = Anonymous, backend = { backend | jwt = Nothing } }
                    , if is502 err then
                        Cmd.batch
                            [ toastError "Server down, please retry" <| httpErrorToString err
                            , case model.route of
                                HomeRoute ->
                                    Routing.goToBestTable model model.game.table True

                                _ ->
                                    Cmd.none
                            ]

                      else
                        Cmd.batch
                            [ toastError "Could not sign in, please retry" <| httpErrorToString err
                            , case model.route of
                                HomeRoute ->
                                    Routing.goToBestTable model model.game.table True

                                _ ->
                                    Cmd.none
                            ]
                    )

                Ok ( profile, token, preferences ) ->
                    let
                        backend =
                            model.backend

                        backend_ =
                            { backend | jwt = Just token }

                        game =
                            Game.State.setUser model.game profile

                        model_ =
                            { model | user = Logged profile, preferences = preferences, backend = backend_, game = game }
                    in
                    ( model_
                    , case model.route of
                        HomeRoute ->
                            Routing.goToBestTable model_ model_.game.table True

                        _ ->
                            Cmd.none
                    )

        GetOtherProfile res ->
            case res of
                Err err ->
                    case err of
                        BadStatus status ->
                            case status of
                                409 ->
                                    ( model
                                    , toastError "This is a bot, nothing to see here." <| httpErrorToString err
                                    )

                                _ ->
                                    ( model
                                    , toastError "Could not fetch profile" <| httpErrorToString err
                                    )

                        _ ->
                            ( model
                            , toastError "Could not fetch profile" <| httpErrorToString err
                            )

                Ok profile ->
                    ( { model | otherProfile = Placeholder.Fetched profile }
                    , Cmd.none
                    )

        UpdateUser profile token preferences ->
            let
                backend =
                    model.backend

                backend_ =
                    { backend | jwt = Just token }
            in
            ( { model | user = Logged profile, preferences = preferences, backend = backend_ }
            , Cmd.none
            )

        Authorize state ->
            ( model, MyOauth.authorize model.oauth state )

        Logout ->
            let
                backend =
                    model.backend

                backend_ =
                    { backend | jwt = Nothing }
            in
            ( { model | user = Anonymous, backend = backend_ }
            , Cmd.batch
                [ MyOauth.saveToken Nothing
                , case model.game.player of
                    Just _ ->
                        sendGameCommand model.backend model.game.table Game.Types.Leave

                    Nothing ->
                        Cmd.none
                , navigateTo model.zip model.key HomeRoute
                , renounceNotifications <| model.backend.jwt
                , ga [ "send", "event", "auth", "Logout" ]
                ]
            )

        SetLoginName text ->
            ( { model | loginName = text }
            , Cmd.none
            )

        SetLoginPassword action ->
            let
                loginPassword =
                    model.loginPassword
            in
            case action of
                StepNext step joinTable ->
                    if step /= loginPassword.step then
                        let
                            loginPassword_ =
                                { loginPassword | step = step }

                            animations =
                                loginPassword.animations
                        in
                        ( { model
                            | loginPassword =
                                { loginPassword_
                                    | animations =
                                        ( Animation.queue
                                            [ Animation.to
                                                [ Animation.left <|
                                                    Animation.percent <|
                                                        if step == 1 then
                                                            -100

                                                        else
                                                            0
                                                ]
                                            ]
                                          <|
                                            Tuple.first animations
                                        , Animation.queue
                                            [ Animation.to
                                                [ Animation.left <|
                                                    Animation.percent <|
                                                        if step == 1 then
                                                            0

                                                        else
                                                            100
                                                ]
                                            ]
                                          <|
                                            Tuple.second animations
                                        )
                                }
                          }
                        , if step == 1 then
                            Browser.Dom.focus "login-dialog-password" |> Task.attempt (\_ -> Nop)

                          else
                            Browser.Dom.focus "login-dialog-email" |> Task.attempt (\_ -> Nop)
                        )

                    else if step == 1 then
                        ( { model
                            | dialog = Hide
                            , loginPassword =
                                { step = 0
                                , email = ""
                                , password = ""
                                , animations =
                                    ( Animation.style [ Animation.left <| Animation.percent 0 ]
                                    , Animation.style [ Animation.left <| Animation.percent 100 ]
                                    )
                                }
                          }
                        , login model model.loginPassword.email model.loginPassword.password joinTable
                        )

                    else
                        ( model, Cmd.none )

                StepEmail value ->
                    ( { model | loginPassword = { loginPassword | email = value } }
                    , Cmd.none
                    )

                StepPassword value ->
                    ( { model | loginPassword = { loginPassword | password = value } }
                    , Cmd.none
                    )

        SetPassword ( email, password ) passwordCheck ->
            ( model
            , Backend.HttpCommands.updatePassword model.backend ( email, password ) passwordCheck
            )

        ShowLogin show ->
            ( { model
                | dialog =
                    case show of
                        LoginShow ->
                            Show Login

                        LoginShowJoin ->
                            Show LoginJoin

                        LoginHide ->
                            Hide
              }
            , Cmd.none
            )

        ShowDialog type_ ->
            ( { model | dialog = Show type_ }
            , Cmd.none
            )

        HideDialog ->
            ( { model | dialog = Hide }
            , Cmd.none
            )

        Register name joinTable ->
            register model name joinTable

        NavigateTo route ->
            ( model
            , Cmd.batch
                [ navigateTo model.zip model.key route
                , Task.perform (\_ -> Nop) (Browser.Dom.setViewport 0 0)
                ]
            )

        OnUrlRequest urlRequest ->
            case urlRequest of
                Browser.Internal url ->
                    ( model
                    , Cmd.batch
                        [ Browser.Navigation.pushUrl model.key <|
                            Url.toString <|
                                if not model.zip then
                                    url

                                else
                                    Url.Url url.protocol
                                        url.host
                                        url.port_
                                        ""
                                        url.query
                                    <|
                                        Just <|
                                            String.dropLeft 1 url.path
                        , Task.perform (\_ -> Nop) (Browser.Dom.setViewport 0 0)
                        ]
                    )

                Browser.External urlString ->
                    ( model, Browser.Navigation.load urlString )

        OnLocationChange url ->
            onLocationChange model <|
                if model.zip then
                    Routing.fragmentUrl url

                else
                    url

        ErrorToast message debugMessage ->
            ( model
            , toastError message debugMessage
            )

        MessageToast message ms ->
            ( model
            , toastMessage message ms
            )

        RuntimeError message debugMessage ->
            ( model
            , Cmd.batch
                [ toastError message debugMessage
                , sentry debugMessage
                ]
            )

        Animate animateMsg ->
            let
                game =
                    model.game

                board =
                    Board.updateAnimations game.board animateMsg

                loginPassword =
                    model.loginPassword
            in
            ( { model
                | game = { game | board = board }
                , loginPassword =
                    { loginPassword
                        | animations =
                            ( Animation.update animateMsg <| Tuple.first loginPassword.animations
                            , Animation.update animateMsg <| Tuple.second loginPassword.animations
                            )
                    }
                , replayer =
                    case model.route of
                        GamesRoute sub ->
                            case sub of
                                GameId _ _ ->
                                    Maybe.map
                                        (\replayer ->
                                            { replayer | board = Board.updateAnimations replayer.board animateMsg }
                                        )
                                        model.replayer

                                _ ->
                                    model.replayer

                        _ ->
                            model.replayer
              }
            , Cmd.none
            )

        BoardMsg boardMsg ->
            let
                game =
                    model.game
            in
            case boardMsg of
                Board.Types.ClickLand emoji ->
                    Game.State.clickLand model emoji

                Board.Types.HoverLand land ->
                    let
                        game_ =
                            { game
                                | hovered =
                                    case game.hovered of
                                        Just h ->
                                            if h /= land then
                                                Just land

                                            else
                                                game.hovered

                                        Nothing ->
                                            Just land
                            }
                    in
                    ( { model | game = game_ }, Cmd.none )

                Board.Types.UnHoverLand land ->
                    if Just land == game.hovered then
                        let
                            game_ =
                                { game | hovered = Nothing }
                        in
                        ( { model | game = game_ }, Cmd.none )

                    else
                        ( model, Cmd.none )

        InputChat text ->
            let
                game =
                    model.game

                game_ =
                    { game | chatInput = text }
            in
            ( { model | game = game_ }
            , Cmd.none
            )

        SendChat string ->
            let
                game =
                    model.game

                game_ =
                    { game | chatInput = "" }
            in
            if string /= "" then
                ( { model | game = game_ }
                , sendGameCommand model.backend model.game.table <| Game.Types.Chat string
                )

            else
                ( model, Cmd.none )

        GameCmd playerAction ->
            gameCommand model playerAction

        EnterGame table ->
            -- now the player is really in a game/table
            let
                enter =
                    Backend.MqttCommands.enter model.backend table

                cmds =
                    Cmd.batch <|
                        [ enter, Cmd.none ]
            in
            ( model
            , cmds
            )

        FindGame current ->
            ( model
            , case Routing.findBestTable model current of
                Nothing ->
                    toastError "Could't find a better table for you" "FindGame: no best table"

                Just table ->
                    Routing.navigateTo model.zip model.key <| GameRoute table
            )

        UnknownTopicMessage error topic message clientId ->
            ( model
            , toastError "I/O Error" <| "UnknownTopicMessage \"" ++ error ++ "\" in topic " ++ topic ++ " with clientId " ++ clientId
            )

        StatusConnect _ ->
            ( Backend.setStatus model Connecting
            , Cmd.none
            )

        StatusReconnect attemptCount ->
            ( Backend.reset model <| Reconnecting attemptCount
            , Cmd.none
            )

        StatusOffline _ ->
            ( Backend.reset model Offline
            , Cmd.none
            )

        StatusError error ->
            ( Backend.reset model Offline
            , toastError error error
            )

        Connected clientId ->
            Backend.updateConnected model clientId

        Subscribed topic ->
            Backend.updateSubscribed model topic

        ClientMsg _ ->
            ( model
            , Cmd.none
            )

        AllClientsMsg allClientsMsg ->
            case allClientsMsg of
                Backend.Types.TablesInfo tables ->
                    let
                        ( game_, gameCmd ) =
                            Game.State.updateGameInfo ( model.game, Cmd.none ) tables
                    in
                    ( { model | tableList = tables, game = game_ }
                    , gameCmd
                    )

                Backend.Types.SigInt ->
                    ( model, toastMessage "Server is restarting..." <| Just 3000 )

                Backend.Types.Toast message ->
                    ( model, toastMessage message <| Just 20000 )

                Backend.Types.ServerOnline version message ->
                    if
                        String.length version
                            > 0
                            && String.length model.backend.version
                            > 0
                            && model.backend.version
                            /= "dev"
                            && version
                            /= "dev"
                            && version
                            /= model.backend.version
                    then
                        ( model, toastMessage "New version has been deployed, please refresh the page" <| Just 30000 )

                    else
                        ( model, toastMessage message <| Just 10000 )

        TableMsg table tableMsg ->
            Game.State.updateTable model table tableMsg

        GameMsg gameMsg ->
            Game.State.update model model.game gameMsg

        Tick newTime ->
            let
                cmd =
                    case model.route of
                        GameRoute table ->
                            case model.backend.clientId of
                                Just c ->
                                    if Time.posixToMillis newTime - Time.posixToMillis model.backend.lastHeartbeat > 5000 then
                                        sendGameCommand model.backend model.game.table Heartbeat

                                    else
                                        Cmd.none

                                Nothing ->
                                    Cmd.none

                        _ ->
                            Cmd.none

                game =
                    model.game

                game_ =
                    case game.chatOverlay of
                        Just ( t, entry ) ->
                            if Time.posixToMillis newTime - Time.posixToMillis t > 10000 then
                                { game | chatOverlay = Nothing }

                            else
                                game

                        Nothing ->
                            game
            in
            ( { model | time = newTime, game = game_ }, cmd )

        UserZone zone ->
            ( { model | zone = zone }, Cmd.none )

        SetLastHeartbeat time ->
            let
                backend =
                    model.backend
            in
            ( { model | backend = { backend | lastHeartbeat = time } }, Cmd.none )

        RequestFullscreen ->
            ( model, requestFullscreen () )

        RequestNotifications ->
            ( model, requestNotifications () )

        RenounceNotifications ->
            ( model, renounceNotifications Nothing )

        NotificationsChange ( permission, subscription, jwt ) ->
            let
                sessionPreferences =
                    model.sessionPreferences

                notificationsEnabled =
                    case permission of
                        "granted" ->
                            True

                        _ ->
                            False

                sessionPreferences_ =
                    { sessionPreferences | notificationsEnabled = notificationsEnabled }
            in
            ( { model | sessionPreferences = sessionPreferences_ }
            , if sessionPreferences_.notificationsEnabled then
                Cmd.none

              else
                case subscription of
                    Just sub ->
                        registerPush model.backend ( sub, False ) jwt

                    Nothing ->
                        toastError "Could not get push subscription to remove!" "empty subscription"
            )

        PushGetKey ->
            ( model, getPushKey model.backend )

        PushKey res ->
            case res of
                Ok key ->
                    ( model, pushSubscribe key )

                Err err ->
                    ( model, toastError "Could not get push key" <| httpErrorToString err )

        PushRegister subscription ->
            ( model, registerPush model.backend ( subscription, True ) Nothing )

        PushRegisterEvent ( event, enable ) ->
            ( model, registerPushEvent model.backend ( event, enable ) )

        SetSessionPreference preference ->
            let
                preferences =
                    model.sessionPreferences
            in
            case preference of
                Muted muted ->
                    ( { model
                        | sessionPreferences =
                            { preferences | muted = muted }
                      }
                    , setSessionPreference
                        ( "muted"
                        , if muted then
                            "true"

                          else
                            "false"
                        )
                    )

        GetComments kind res ->
            Comments.got model kind res

        InputComment kind value ->
            Comments.input model kind value

        ReplyComment kind to ->
            Comments.reply model kind to

        PostComment kind parentKind text ->
            Comments.post model kind parentKind text

        GetPostComment kind parentKind res ->
            Comments.posted model kind parentKind res

        Resized w h ->
            ( setPortrait model w h, Cmd.none )

        ExpandChats ->
            let
                game =
                    model.game

                game_ =
                    { game | expandChat = not game.expandChat }
            in
            ( { model | game = game_ }, Cmd.none )

        ReplayerCmd cmd ->
            Games.Replayer.update model cmd

        NotificationClick tag ->
            case tag of
                _ ->
                    ( model, Helpers.consoleDebug <| "click notification: " ++ tag )

        PushNotification json ->
            ( model, Helpers.consoleDebug <| "push notification: " ++ json )


tableFromRoute : Route -> Maybe Table
tableFromRoute route =
    case route of
        GameRoute table ->
            Just table

        _ ->
            Nothing


setPortrait : Model -> Int -> Int -> Model
setPortrait model w h =
    { model | fullscreen = w <= 840 && (toFloat w / toFloat h) > 13 / 9 }


view : Model -> Browser.Document Msg
view model =
    { title = "Qdice.wtf"
    , body =
        [ dialog model
        , Html.main_ [ Html.Attributes.class "Main" ]
            [ mainView model
            ]
        , footer model
        ]
    }


mainView : Model -> Html.Html Msg
mainView model =
    case model.route of
        HomeRoute ->
            viewWrapper
                [ Html.text "Searching for a table..." ]

        GameRoute table ->
            Game.View.view model

        StaticPageRoute page ->
            viewWrapper
                [ Static.View.view model page
                ]

        NotFoundRoute ->
            viewWrapper
                [ Html.text "404" ]

        MyProfileRoute ->
            viewWrapper
                [ case model.user of
                    Anonymous ->
                        Html.text "You are not logged in."

                    Logged user ->
                        MyProfile.MyProfile.view model.myProfile user model.preferences model.sessionPreferences
                ]

        TokenRoute token ->
            viewWrapper
                [ Html.text "Getting user ready..." ]

        ProfileRoute id name ->
            viewWrapper
                [ Profile.view model id name ]

        LeaderBoardRoute ->
            viewWrapper
                [ LeaderBoard.View.view model ]

        GamesRoute sub ->
            viewWrapper
                [ Games.view model sub ]


viewWrapper : List (Html.Html Msg) -> Html.Html Msg
viewWrapper =
    Html.div [ Html.Attributes.class "edMainScreen edMainScreen__static" ]


mainViewSubscriptions : Model -> Sub Msg
mainViewSubscriptions model =
    Sub.batch <|
        [ Animation.subscription Animate <|
            (case model.route of
                GameRoute _ ->
                    Board.animations model.game.board

                GamesRoute sub ->
                    case sub of
                        GameId _ _ ->
                            case model.replayer of
                                Just replayer ->
                                    Board.animations replayer.board

                                -- ++ [ Games.Replayer.subscriptions model.replayer ]
                                Nothing ->
                                    []

                        _ ->
                            []

                _ ->
                    []
            )
                ++ [ Tuple.first model.loginPassword.animations
                   , Tuple.second model.loginPassword.animations
                   ]
        ]
            ++ (case model.route of
                    GamesRoute sub ->
                        case sub of
                            GameId _ _ ->
                                case model.replayer of
                                    Just replayer ->
                                        [ Games.Replayer.subscriptions replayer ]

                                    Nothing ->
                                        []

                            _ ->
                                []

                    _ ->
                        []
               )


onLocationChange : Model -> Url -> ( Model, Cmd Msg )
onLocationChange model location =
    let
        newRoute =
            parseLocation location

        ( model_, cmd ) =
            Routing.routeEnterCmd { model | route = newRoute } newRoute
    in
    if newRoute == model.route then
        ( model
        , Cmd.none
        )

    else
        ( model_, cmd )
            |> (case newRoute of
                    GameRoute table ->
                        pipeUpdates Game.State.changeTable table

                    _ ->
                        identity
               )
            |> (case model.route of
                    GameRoute table ->
                        pipeUpdates Backend.unsubscribeGameTable table

                    _ ->
                        identity
               )


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ mainViewSubscriptions model
        , Backend.subscriptions model
        , Time.every 250 Tick
        , Browser.Events.onResize Resized
        , notificationsChange NotificationsChange
        , pushGetKey (\_ -> PushGetKey)
        , pushRegister PushRegister
        , Helpers.notificationClick NotificationClick
        , Helpers.pushNotification PushNotification
        ]


port started : String -> Cmd msg


port requestFullscreen : () -> Cmd msg


port requestNotifications : () -> Cmd msg


port renounceNotifications : Maybe String -> Cmd msg


port notificationsChange : (( String, Maybe PushSubscription, Maybe String ) -> msg) -> Sub msg


port pushGetKey : (() -> msg) -> Sub msg


port pushSubscribe : String -> Cmd msg


port pushRegister : (PushSubscription -> msg) -> Sub msg


port setSessionPreference : ( String, String ) -> Cmd msg


port sentry : String -> Cmd msg
