port module Edice exposing (init, pushSubscribe, started, subscriptions, updateWrapper, view)

import Animation
import Backend
import Backend.HttpCommands exposing (authenticate, getPushKey, loadGlobalSettings, loadMe, login, registerPush, registerPushEvent)
import Backend.MqttCommands exposing (sendGameCommand)
import Backend.Types exposing (ConnectionStatus(..), TableMessage(..), TopicDirection(..))
import Board
import Board.Types
import Browser
import Browser.Dom
import Browser.Navigation exposing (Key)
import Footer exposing (footer)
import GA exposing (ga)
import Game.State exposing (gameCommand)
import Game.Types exposing (PlayerAction(..))
import Game.View
import Helpers exposing (httpErrorToString, pipeUpdates)
import Html
import Html.Attributes
import Http exposing (Error(..))
import LeaderBoard.State
import LeaderBoard.View
import LoginDialog exposing (loginDialog)
import MyOauth
import MyProfile.MyProfile
import MyProfile.Types
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

        game =
            Game.State.init table Nothing

        ( backend, backendCmd ) =
            Backend.init flags.version location flags.token flags.isTelegram

        ( oauth, oauthCmds ) =
            MyOauth.init key location

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

        model : Model
        model =
            { route = route
            , key = key
            , oauth = oauth
            , game = game
            , myProfile = { name = Nothing, email = Nothing, picture = Nothing, deleteAccount = MyProfile.Types.None }
            , backend = backend_
            , user = Types.Anonymous
            , tableList = []
            , time = Time.millisToPosix 0
            , isTelegram = flags.isTelegram
            , screenshot = flags.screenshot
            , zip = flags.zip
            , loginName = ""
            , showLoginDialog = LoginHide
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
                }
            , leaderBoard =
                { loading = False
                , month = "this month"
                , top = []
                , board = []
                , page = 1
                }
            , otherProfile = Nothing
            }

        ( model_, routeCmd ) =
            Routing.routeEnterCmd model route

        cmds =
            Cmd.batch <|
                List.concat
                    [ routeCmds
                    , [ started "peekaboo"
                      , backendCmd
                      ]
                    , oauthCmds
                    , [ loadGlobalSettings backend ]
                    , [ routeCmd ]
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

        GetGlobalSettings res ->
            case res of
                Err err ->
                    ( model, toastError "Could not load global configuration!" <| httpErrorToString err )

                Ok ( settings, tables, ( month, top ) ) ->
                    let
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
                    in
                    case model.route of
                        GameRoute table ->
                            case model.backend.status of
                                Online ->
                                    Game.State.changeTable model_ table

                                _ ->
                                    Game.State.changeTable model_ table

                        HomeRoute ->
                            ( model_, Routing.goToBestTable model_ )

                        _ ->
                            ( model_, Cmd.none )

        GetToken authState res ->
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
                                    Maybe.andThen .table authState
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
                                    case Maybe.andThen .table authState of
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

        GetProfile res ->
            case res of
                Err err ->
                    ( model
                    , toastError "Could not sign in, please retry" <| httpErrorToString err
                    )

                Ok ( profile, token, preferences ) ->
                    let
                        backend =
                            model.backend

                        backend_ =
                            { backend | jwt = Just token }

                        game =
                            Game.State.setUser model.game profile
                    in
                    ( { model | user = Logged profile, preferences = preferences, backend = backend_, game = game }
                    , ga [ "send", "event", "auth", "GetProfile" ]
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
                    ( { model | otherProfile = Just profile }
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

        Authenticate code state ->
            ( model
            , Cmd.batch
                [ authenticate model.backend code state
                , ga [ "send", "event", "auth", "Authenticate" ]
                ]
            )

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

        ShowLogin show ->
            ( { model | showLoginDialog = show }
            , Cmd.none
            )

        Login name ->
            login model name

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

        Animate animateMsg ->
            let
                game =
                    model.game

                ( board, cmds ) =
                    Board.updateAnimations game.board animateMsg
            in
            ( { model
                | game =
                    { game
                        | board = board
                    }
              }
            , Cmd.map BoardMsg cmds
            )

        BoardMsg boardMsg ->
            let
                game =
                    model.game

                ( board, newBoardMsg ) =
                    Board.update boardMsg model.game.board

                game_ =
                    { game | board = board }

                model_ =
                    { model | game = game_ }
            in
            case boardMsg of
                Board.Types.ClickLand land ->
                    Game.State.clickLand model_ land

                -- Board.Types.HoverLand land ->
                -- Game.State.hoverLand model_ land
                _ ->
                    ( model_
                    , Cmd.map BoardMsg newBoardMsg
                    )

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

                totalPlayers =
                    List.sum <| List.map .playerCount <| model.tableList

                cmds =
                    Cmd.batch <|
                        [ enter, Cmd.none ]
            in
            ( model
            , cmds
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
                        game =
                            model.game

                        game_ =
                            Game.State.updateGameInfo model.game tables
                    in
                    ( { model | tableList = tables, game = game_ }
                    , Cmd.none
                    )

                Backend.Types.SigInt ->
                    ( model, toastMessage "Server is restarting..." <| Just 3000 )

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
            in
            if Time.posixToMillis newTime |> toFloat |> (*) 0.001 |> floor |> remainderBy 5 |> (==) 0 then
                let
                    game =
                        model.game

                    board =
                        game.board
                in
                ( { model | time = newTime, game = { game | board = Board.clearCssAnimations board newTime } }, cmd )

            else
                ( model, cmd )

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


tableFromRoute : Route -> Maybe Table
tableFromRoute route =
    case route of
        GameRoute table ->
            Just table

        _ ->
            Nothing


view : Model -> Browser.Document Msg
view model =
    { title = "Qdice.wtf"
    , body =
        [ loginDialog model
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


viewWrapper : List (Html.Html Msg) -> Html.Html Msg
viewWrapper =
    Html.div [ Html.Attributes.class "edMainScreen edMainScreen__static" ]


mainViewSubscriptions : Model -> Sub Msg
mainViewSubscriptions model =
    case model.route of
        GameRoute _ ->
            let
                list =
                    Board.animations model.game.board
            in
            Animation.subscription Animate list

        _ ->
            Sub.none


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
        , Time.every 1000 Tick
        , notificationsChange NotificationsChange
        , pushGetKey (\_ -> PushGetKey)
        , pushRegister PushRegister
        ]


port started : String -> Cmd msg


port requestFullscreen : () -> Cmd msg


port requestNotifications : () -> Cmd msg


port renounceNotifications : Maybe String -> Cmd msg


port notificationsChange : (( String, Maybe PushSubscription, Maybe String ) -> msg) -> Sub msg


port pushGetKey : (() -> msg) -> Sub msg


port pushSubscribe : String -> Cmd msg


port pushRegister : (PushSubscription -> msg) -> Sub msg
