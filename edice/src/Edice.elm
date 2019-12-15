port module Edice exposing (pushSubscribe, started, subscriptions)

import Animation
import Backend
import Backend.HttpCommands exposing (authenticate, getPushKey, loadGlobalSettings, loadMe, login, registerPush)
import Backend.MqttCommands exposing (sendGameCommand)
import Backend.Types exposing (ConnectionStatus(..), TableMessage(..), TopicDirection(..))
import Board
import Board.Types
import Browser
import Browser.Navigation exposing (Key)
import Footer exposing (footer)
import GA exposing (ga)
import Game.State exposing (gameCommand)
import Game.Types exposing (PlayerAction(..))
import Game.View
import Helpers exposing (httpErrorToString, pipeUpdates)
import Html
import Html.Attributes
import LeaderBoard.State
import LeaderBoard.View
import LoginDialog exposing (loginDialog)
import MyOauth
import MyProfile.MyProfile
import MyProfile.Types
import Routing exposing (navigateTo, parseLocation)
import Snackbar exposing (toastError)
import Static.View
import Tables exposing (Map(..), Table)
import Time
import Types exposing (..)
import Url exposing (Url)


type alias Flags =
    { version : String
    , token : Maybe String
    , isTelegram : Bool
    , screenshot : Bool
    , notificationsEnabled : Bool
    }


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , view = view
        , update = updateWrapper
        , subscriptions = subscriptions
        , onUrlRequest = OnUrlRequest
        , onUrlChange = OnLocationChange
        }


init : Flags -> Url -> Key -> ( Model, Cmd Msg )
init flags location key =
    let
        route =
            Routing.parseLocation location

        table =
            currentTable route

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
                      , navigateTo key <| GameRoute ""
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
            , myProfile = { name = Nothing, email = Nothing, deleteAccount = MyProfile.Types.None }
            , backend = backend_
            , user = Types.Anonymous
            , tableList = []
            , time = Time.millisToPosix 0
            , isTelegram = flags.isTelegram
            , screenshot = flags.screenshot
            , loginName = ""
            , showLoginDialog = LoginHide
            , settings =
                { gameCountdownSeconds = 30
                , maxNameLength = 20
                , turnSeconds = 10
                }
            , preferences =
                { notificationsEnabled = flags.notificationsEnabled
                , anyGameStartNotify = False
                }
            , leaderBoard =
                { month = "this month"
                , top = []
                }
            }

        cmds =
            Cmd.batch <|
                List.concat
                    [ routeCmds
                    , [ started "peekaboo"
                      , backendCmd
                      ]
                    , oauthCmds
                    , [ loadGlobalSettings backend ]
                    , [ Routing.routeEnterCmd model route ]
                    ]
    in
    ( model, cmds )


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
                                    { month = month
                                    , top = top
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

                        --( model_, Cmd.none )
                        HomeRoute ->
                            ( model_, Routing.goToBestTable model_ )

                        _ ->
                            ( model_, Cmd.none )

        GetToken table res ->
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

                        model_ =
                            { model | backend = backend_ }
                    in
                    ( model_
                    , Cmd.batch
                        [ MyOauth.saveToken <| Just token
                        , loadMe backend_
                        , sendGameCommand model_.backend model.game.table Game.Types.Join
                        ]
                    )

        GetProfile res ->
            case res of
                Err err ->
                    ( model
                    , toastError "Could not sign in, please retry" <| httpErrorToString err
                    )

                Ok ( profile, token ) ->
                    let
                        backend =
                            model.backend

                        backend_ =
                            { backend | jwt = Just token }
                    in
                    ( { model | user = Logged profile, backend = backend_ }
                    , ga [ "send", "event", "auth", "GetProfile" ]
                    )

        GetLeaderBoard res ->
            LeaderBoard.State.setLeaderBoard model res

        UpdateUser profile token ->
            let
                backend =
                    model.backend

                backend_ =
                    { backend | jwt = Just token }
            in
            ( { model | user = Logged profile, backend = backend_ }
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
                , navigateTo model.key HomeRoute
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
            , navigateTo model.key route
            )

        OnUrlRequest urlRequest ->
            case urlRequest of
                Browser.Internal location ->
                    ( model, Browser.Navigation.pushUrl model.key <| Url.toString location )

                Browser.External urlString ->
                    ( model, Browser.Navigation.load urlString )

        OnLocationChange location ->
            onLocationChange model location

        ErrorToast message debugMessage ->
            ( model
            , toastError message debugMessage
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

        UnknownTopicMessage error topic message ->
            ( model
            , toastError "I/O Error" <| "UnknownTopicMessage \"" ++ error ++ "\" in topic " ++ topic
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

        TableMsg table tableMsg ->
            Game.State.updateTable model table tableMsg

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
            ( { model | time = newTime }, cmd )

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

        NotificationsChange permission ->
            let
                preferences =
                    model.preferences

                notificationsEnabled =
                    case permission of
                        "granted" ->
                            True

                        _ ->
                            False

                preferences_ =
                    { preferences | notificationsEnabled = notificationsEnabled }
            in
            ( { model | preferences = preferences_ }, Cmd.none )

        PushGetKey ->
            ( model, getPushKey model.backend )

        PushKey res ->
            case res of
                Ok key ->
                    ( model, pushSubscribe key )

                Err err ->
                    ( model, toastError "Could not get push key" <| httpErrorToString err )

        PushRegister subscription ->
            ( model, registerPush model.backend subscription )


currentTable : Route -> Maybe Table
currentTable route =
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
                        MyProfile.MyProfile.view model.myProfile user
                ]

        TokenRoute token ->
            viewWrapper
                [ Html.text "Getting user ready..." ]

        ProfileRoute id ->
            viewWrapper
                [ Html.text "WIP" ]

        LeaderBoardRoute ->
            viewWrapper
                [ LeaderBoard.View.view 1000 model ]


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

        model_ =
            { model | route = newRoute }

        cmd =
            Routing.routeEnterCmd model_ newRoute
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
        , notificationsChange NotificationsChange
        , pushGetKey (\_ -> PushGetKey)
        , pushRegister PushRegister
        ]


port started : String -> Cmd msg


port requestFullscreen : () -> Cmd msg


port requestNotifications : () -> Cmd msg


port notificationsChange : (String -> msg) -> Sub msg


port pushGetKey : (() -> msg) -> Sub msg


port pushSubscribe : String -> Cmd msg


port pushRegister : (PushSubscription -> msg) -> Sub msg
