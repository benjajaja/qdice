port module Edice exposing (..)

import Task
import Maybe
import Navigation exposing (Location)
import Routing exposing (parseLocation, navigateTo)
import Html
import Html.Lazy
import Html.Attributes
import Time
import Http
import Material
import Material.Layout as Layout
import Material.Icon as Icon
import Material.Options
import Material.Footer as Footer
import Material.Menu as Menu
import Animation
import Types exposing (..)
import Game.Types exposing (PlayerAction(..))
import Game.State
import Game.View
import Game.Chat
import Board
import Board.Types
import Static.View
import Editor.Editor
import MyProfile.MyProfile
import Backend
import Backend.HttpCommands exposing (authenticate, loadMe, loadGlobalSettings, findBestTable)
import Backend.MqttCommands exposing (gameCommand)
import Backend.Types exposing (TableMessage(..), TopicDirection(..), ConnectionStatus(..))
import Tables exposing (Table(..), tableList)
import MyOauth
import Snackbar exposing (toast)
import Footer exposing (footer)
import Drawer exposing (drawer)
import LoginDialog exposing (loginDialog, login)
import Helpers exposing (pipeUpdates)
import LeaderBoard.State
import LeaderBoard.View


type alias Flags =
    { isTelegram : Bool
    }


main : Program Flags Model Msg
main =
    Navigation.programWithFlags OnLocationChange
        { init = init
        , view = view
        , update = updateWrapper
        , subscriptions = subscriptions
        }


init : Flags -> Location -> ( Model, Cmd Msg )
init flags location =
    let
        route =
            Routing.parseLocation location

        table =
            Maybe.withDefault Melchor <| currentTable route

        ( game, gameCmd ) =
            Game.State.init Nothing table

        ( editor, editorCmd ) =
            Editor.Editor.init

        ( backend, backendCmd ) =
            Backend.init location table flags.isTelegram

        ( oauth, oauthCmds ) =
            MyOauth.init location

        ( backend_, routeCmds ) =
            case route of
                TokenRoute token ->
                    let
                        backend_ =
                            { backend | jwt = Just token }
                    in
                        ( backend_
                        , [ auth [ token ]
                          , loadMe backend_
                          , navigateTo <| GameRoute Melchor
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

        model =
            { route = route
            , mdl = Material.model
            , oauth = oauth
            , game = game
            , editor = editor
            , myProfile = { name = Nothing }
            , backend = backend_
            , user = Types.Anonymous
            , tableList = []
            , time = 0
            , snackbar = Snackbar.init
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
                      , Cmd.map EditorMsg editorCmd
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
            model ! []

        EditorMsg msg ->
            let
                ( editor, editorCmd ) =
                    Editor.Editor.update msg model.editor
            in
                ( { model | editor = editor }, Cmd.map EditorMsg editorCmd )

        MyProfileMsg msg ->
            MyProfile.MyProfile.update model msg

        StaticPageMsg msg ->
            Static.View.update model msg

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
                            model.game

                        game_ =
                            Game.State.updateGameInfo model.game tables
                    in
                        { model | settings = settings, tableList = tables, game = game_ } ! []

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
                        model_
                            ! [ auth [ token ]
                              , loadMe backend_
                              , (if doJoin then
                                    gameCommand model_.backend model_.game.table Game.Types.Join
                                 else
                                    Cmd.none
                                )
                              ]

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
                        { model | user = Logged profile, backend = backend_ } ! []

        GetLeaderBoard res ->
            LeaderBoard.State.setLeaderBoard model res

        UpdateUser profile token ->
            let
                backend =
                    model.backend

                backend_ =
                    { backend | jwt = Just token }
            in
                { model | user = Logged profile, backend = backend_ } ! []

        Authorize doJoin ->
            MyOauth.authorize model doJoin

        LoadToken token ->
            let
                backend =
                    model.backend

                backend_ =
                    { backend | jwt = Just token }
            in
                { model | backend = backend_ }
                    ! [ loadMe backend_ ]

        Authenticate code doJoin ->
            model ! [ authenticate model.backend code doJoin ]

        Logout ->
            let
                backend =
                    model.backend

                backend_ =
                    { backend | jwt = Nothing }

                player =
                    Game.State.findUserPlayer model.user model.game.players
            in
                { model | user = Anonymous, backend = backend_ }
                    ! [ auth []
                      , (case player of
                            Just _ ->
                                gameCommand model.backend model.game.table Game.Types.Leave

                            Nothing ->
                                Cmd.none
                        )
                      ]

        SetLoginName text ->
            { model | loginName = text } ! []

        ShowLogin show ->
            { model | showLoginDialog = Debug.log "login" show }
                ! if model.mdl.layout.isDrawerOpen then
                    msgsToCmds [ Layout.toggleDrawer Mdl ]
                  else
                    []

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
                        ( model, navigateTo <| GameRoute Melchor )

                Ok table ->
                    ( model, navigateTo <| GameRoute table )

        NavigateTo route ->
            model ! [ navigateTo route ]

        DrawerNavigateTo route ->
            model ! msgsToCmds [ Layout.toggleDrawer Mdl, NavigateTo route ]

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
                    model ! []
                else
                    ( model_, cmd )
                        |> (case newRoute of
                                GameRoute table ->
                                    pipeUpdates Game.State.changeTable table

                                --HomeRoute ->
                                --(\( m, c ) -> m ! [ navigateTo <| GameRoute Melchor, c ])
                                _ ->
                                    identity
                           )
                        |> case model.route of
                            GameRoute table ->
                                pipeUpdates Backend.unsubscribeGameTable table

                            _ ->
                                identity

        Mdl msg ->
            Material.update Mdl msg model

        Snackbar snackbarMsg ->
            let
                ( snackbar_, cmd ) =
                    Snackbar.update snackbarMsg model.snackbar
            in
                { model | snackbar = snackbar_ } ! [ Cmd.map Snackbar cmd ]

        ErrorToast message ->
            toast model <| Debug.log "error" message

        Animate msg ->
            let
                game =
                    model.game

                board =
                    game.board
            in
                ( { model
                    | game =
                        { game
                            | board = Board.updateAnimations board (Animation.update msg)
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
                        model_ ! [ Cmd.map BoardMsg newBoardMsg ]

        InputChat text ->
            let
                game =
                    model.game

                game_ =
                    { game | chatInput = text }
            in
                { model | game = game_ } ! []

        SendChat string ->
            let
                game =
                    model.game

                game_ =
                    { game | chatInput = "" }
            in
                { model | game = game_ }
                    ! [ gameCommand model.backend model.game.table <| Game.Types.Chat string
                        --Backend.Types.Chat (Types.getUsername model) model.game.chatInput
                        --|> TableMsg model.game.table
                        --|> Backend.publish
                      ]

        GameCmd playerAction ->
            model ! [ gameCommand model.backend model.game.table playerAction ]

        UnknownTopicMessage error topic message ->
            let
                _ =
                    Debug.log ("Error in message: \"" ++ error ++ "\"") topic
            in
                model ! []

        StatusConnect _ ->
            (Backend.setStatus Connecting model) ! []

        StatusReconnect attemptCount ->
            (Backend.setStatus (Reconnecting attemptCount) model) ! []

        StatusOffline _ ->
            (Backend.setStatus Offline model) ! []

        Connected clientId ->
            Backend.updateConnected model clientId

        Subscribed topic ->
            Backend.updateSubscribed model topic

        ClientMsg msg ->
            model ! []

        AllClientsMsg msg ->
            case msg of
                Backend.Types.TablesInfo tables ->
                    let
                        game =
                            model.game

                        game_ =
                            Game.State.updateGameInfo model.game tables
                    in
                        { model | tableList = tables, game = game_ } ! []

        TableMsg table msg ->
            Game.State.updateTable model table msg

        Tick newTime ->
            { model | time = newTime } ! []


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


type alias Mdl =
    Material.Model


lazyList : (a -> List (Html.Html Msg)) -> a -> List (Html.Html Msg)
lazyList view =
    Html.Lazy.lazy (\model -> Html.div [] (view model)) >> (\html -> [ html ])


view : Model -> Html.Html Msg
view model =
    Layout.render Mdl
        model.mdl
        [ Layout.scrolling
          --, Layout.fixedHeader
        ]
        { header =
            []
            --(if not model.isTelegram then
            --(lazyList header) model
            --else
            --[]
            --)
        , drawer =
            (if not model.isTelegram then
                (lazyList drawer) model.user
             else
                []
            )
        , tabs = ( [], [] )
        , main =
            [ loginDialog model
            , Html.div [ Html.Attributes.class "Main" ]
                [ mainView model
                ]
            , footer model
            , Snackbar.view model.snackbar |> Html.map Snackbar
            ]
        }


header : Model -> List (Html.Html Msg)
header model =
    [ Layout.row
        [ Material.Options.cs "header" ]
        [ Layout.title [] [ Html.text "¡Qué Dice!" ]
        , Layout.spacer
        , Layout.navigation []
            [ case model.user of
                Logged user ->
                    Html.text user.name

                Anonymous ->
                    Html.text ""
            , Menu.render Mdl
                [ 0 ]
                model.mdl
                [ Menu.bottomRight, Menu.ripple ]
              <|
                case model.user of
                    Logged user ->
                        [ Menu.item
                            [ Menu.onSelect Logout ]
                            [ Html.text "Sign out" ]
                        ]

                    Anonymous ->
                        [ Menu.item
                            [ Menu.onSelect <| Authorize False ]
                            [ Html.text "Sign in" ]
                        ]
            ]
        ]
    ]


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

        EditorRoute ->
            viewWrapper
                [ Editor.Editor.view model ]

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

        -- EditorRoute ->
        --     Editor.Editor.subscriptions model.editor |> Sub.map EditorMsg
        _ ->
            Sub.none


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ mainViewSubscriptions model
        , Backend.subscriptions model
        , Time.every (250) Tick
        , Menu.subs Mdl model.mdl
        ]


port started : String -> Cmd msg


port auth : List String -> Cmd msg
