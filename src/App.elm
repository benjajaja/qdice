port module Edice exposing (auth, started, subscriptions)

import Animation
import Backend
import Backend.HttpCommands exposing (authenticate, findBestTable, loadGlobalSettings, loadMe)
import Backend.MqttCommands exposing (gameCommand)
import Backend.Types exposing (ConnectionStatus(..), TableMessage(..), TopicDirection(..))
import Board
import Board.Types
import Footer exposing (footer)
import GA exposing (ga)
import Game.Chat
import Game.State
import Game.Types exposing (PlayerAction(..))
import Game.View
import Helpers exposing (pipeUpdates)
import Html
import Html.Attributes
import Html.Lazy
import Http
import LeaderBoard.State
import LeaderBoard.View
import LoginDialog exposing (login, loginDialog)
import Material
import Material.Icon as Icon
import Material.Menu as Menu
import Material.Options
import Maybe
import MyOauth
import MyProfile.MyProfile
import Routing exposing (parseLocation, navigateTo, replaceNavigateTo)
import Snackbar exposing (toast)
import Static.View
import Tables exposing (Map(..), Table)
import Task
import Time
import Types exposing (..)
import Browser
import Browser.Navigation exposing (Key)
import Url exposing (Url)


type alias Flags =
    { isTelegram : Bool
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
            Maybe.withDefault "" <| currentTable route

        ( game, gameCmd ) =
            Game.State.init Nothing table Nothing

        ( backend, backendCmd ) =
            Backend.init location table flags.isTelegram

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
                        , [ auth [ token ]
                          , loadMe loadBackend
                          , navigateTo key <| GameRoute ""
                          ]
                        )

                _ ->
                    ( backend
                    , [ case route of
                            HomeRoute ->
                                findBestTable backend

                            _ ->
                                Cmd.none
                      ]
                    )

        model : Model
        model =
            { route = route
            , key = key
            , mdc = Material.defaultModel
            , oauth = oauth
            , game = game
            , myProfile = { name = Nothing }
            , backend = backend_
            , user = Types.Anonymous
            , tableList = []
            , time = Time.millisToPosix 0
            , isTelegram = flags.isTelegram
            , loginName = ""
            , showLoginDialog = LoginHide
            , settings =
                { gameCountdownSeconds = 30
                , maxNameLength = 20
                , turnSeconds = 10
                }
            , staticPage =
                { help =
                    { tab = 0
                    }
                , leaderBoard =
                    { month = "This month"
                    , top = []
                    }
                }
            }

        cmds =
            Cmd.batch <|
                List.concat
                    [ routeCmds
                    , [ gameCmd ]
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
                    let
                        _ =
                            Debug.log "gloal settings error" err
                    in
                        toast model <| "Could not load global configuration!"

                Ok ( settings, tables ) ->
                    let
                        game =
                            Game.State.updateGameInfo model.game tables
                    in
                        ( { model | settings = settings, tableList = tables, game = game }
                        , Cmd.none
                        )

        GetToken doJoin res ->
            case res of
                Err err ->
                    let
                        oauth =
                            model.oauth

                        oauth_ =
                            { oauth | error = Just "unable to fetch user profile ¯\\_(ツ)_/¯" }
                    in
                        toast { model | oauth = oauth_ } <| "Could not load profile"

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
                            [ auth [ token ]
                            , loadMe backend_
                            , if doJoin then
                                gameCommand model_.backend model_.game.table Game.Types.Join
                              else
                                Cmd.none
                            ]
                        )

        GetProfile res ->
            case res of
                Err err ->
                    let
                        _ =
                            Debug.log "error" err
                    in
                        toast model "Could not sign in, please retry"

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

        Authorize doJoin ->
            ( model, MyOauth.authorize model.oauth doJoin )

        LoadToken token ->
            let
                backend =
                    model.backend

                backend_ =
                    { backend | jwt = Just token }
            in
                ( { model | backend = backend_ }
                , Cmd.batch [ loadMe backend_, ga [ "send", "event", "auth", "LoadToken" ] ]
                )

        Authenticate code doJoin ->
            ( model
            , Cmd.batch
                [ authenticate model.backend code doJoin
                , ga [ "send", "event", "auth", "Authenticate" ]
                ]
            )

        Logout ->
            let
                backend =
                    model.backend

                backend_ =
                    { backend | jwt = Nothing }

                player =
                    Game.State.findUserPlayer model.user model.game.players
            in
                ( { model | user = Anonymous, backend = backend_ }
                , Cmd.batch
                    [ auth []
                    , case player of
                        Just _ ->
                            gameCommand model.backend model.game.table Game.Types.Leave

                        Nothing ->
                            Cmd.none
                    , ga [ "send", "event", "auth", "Logout" ]
                    ]
                )

        SetLoginName text ->
            ( { model | loginName = text }
            , Cmd.none
            )

        ShowLogin show ->
            ( { model | showLoginDialog = Debug.log "login" show }
            , Cmd.none
            )

        Login name ->
            login model name

        FindBestTable res ->
            case res of
                Err err ->
                    let
                        _ =
                            Debug.log "error" err
                    in
                        --toast model "Could not find a good table for you"
                        ( model, replaceNavigateTo model.key <| GameRoute "" )

                Ok table ->
                    ( model
                    , if model.route /= GameRoute table then
                        replaceNavigateTo model.key <| GameRoute table
                      else
                        Cmd.none
                    )

        NavigateTo route ->
            ( model
            , navigateTo model.key route
            )

        OnUrlRequest urlRequest ->
            ( model, Cmd.none )

        OnLocationChange location ->
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

        Mdl mdlMsg ->
            Material.update Mdl mdlMsg model

        ErrorToast message ->
            toast model <| Debug.log "error" message

        Animate animateMsg ->
            let
                game =
                    model.game

                board =
                    game.board
            in
                ( { model
                    | game =
                        { game
                            | board = Board.updateAnimations board (Animation.update animateMsg)
                        }
                  }
                , Cmd.none
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

                    Board.Types.HoverLand land ->
                        Game.State.hoverLand model_ land

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
                    , gameCommand model.backend model.game.table <| Game.Types.Chat string
                    )
                else
                    ( model, Cmd.none )

        GameCmd playerAction ->
            ( model
            , gameCommand model.backend model.game.table playerAction
            )

        UnknownTopicMessage error topic message ->
            let
                _ =
                    Debug.log ("Error in message: \"" ++ error ++ "\"") topic
            in
                ( model
                , Cmd.none
                )

        StatusConnect _ ->
            ( Backend.setStatus Connecting model
            , Cmd.none
            )

        StatusReconnect attemptCount ->
            ( Backend.setStatus (Reconnecting attemptCount) model
            , Cmd.none
            )

        StatusOffline _ ->
            ( Backend.setStatus Offline model
            , Cmd.none
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
                                    if Time.posixToMillis newTime - Time.posixToMillis model.backend.lastHeartbeat > 30 then
                                        gameCommand model.backend model.game.table Heartbeat
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


msgsToCmds : List Msg -> List (Cmd Msg)
msgsToCmds msgs =
    List.map (\msg -> Task.perform (always msg) (Task.succeed ())) msgs


currentTable : Route -> Maybe Table
currentTable route =
    case route of
        GameRoute table ->
            Just table

        _ ->
            Nothing


lazyList : (a -> List (Html.Html Msg)) -> a -> List (Html.Html Msg)
lazyList v =
    Html.Lazy.lazy (\model -> Html.div [] (v model)) >> (\html -> [ html ])


view : Model -> Browser.Document Msg
view model =
    { title = "Qdice.wtf"
    , body =
        [ Html.div []
            [ loginDialog model
            , Html.div [ Html.Attributes.class "Main" ]
                [ mainView model
                ]
            , footer model
              --, Snackbar.view model.snackbar |> Html.map Snackbar
            ]
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
                        Html.text "404"

                    Logged user ->
                        MyProfile.MyProfile.view model user
                ]

        TokenRoute token ->
            viewWrapper
                [ Html.text "Getting user ready..." ]

        ProfileRoute id ->
            viewWrapper
                [ Html.text "WIP" ]

        LeaderBoardRoute ->
            viewWrapper
                [ LeaderBoard.View.view model ]


viewWrapper : List (Html.Html Msg) -> Html.Html Msg
viewWrapper =
    Html.div [ Html.Attributes.class "MainBody" ]


mainViewSubscriptions : Model -> Sub Msg
mainViewSubscriptions model =
    case model.route of
        GameRoute _ ->
            Animation.subscription Animate <| Board.animations model.game.board

        _ ->
            Sub.none


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ mainViewSubscriptions model
        , Backend.subscriptions model
        , Time.every 250 Tick
        ]


port started : String -> Cmd msg


port auth : List String -> Cmd msg
