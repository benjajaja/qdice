port module Edice exposing (..)

import Task
import Maybe
import Navigation exposing (Location)
import Routing exposing (parseLocation, navigateTo)
import Html
import Html.Lazy
import Html.Attributes
import Time
import Material
import Material.Layout as Layout
import Material.Icon as Icon
import Material.Options
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
import Backend.Types exposing (TableMessage(..), TopicDirection(..), ConnectionStatus(..))
import Tables exposing (Table(..), tableList)
import MyOauth


main : Program Never Model Msg
main =
    Navigation.program OnLocationChange
        { init = init
        , view = view
        , update = updateWrapper
        , subscriptions = subscriptions
        }


init : Location -> ( Model, Cmd Msg )
init location =
    let
        route =
            Routing.parseLocation location

        table =
            Maybe.withDefault Melchor <| currentTable route

        ( game, gameCmds ) =
            Game.State.init Nothing table

        ( editor, editorCmd ) =
            Editor.Editor.init

        ( backend, backendCmd ) =
            Backend.init location table

        ( oauth, oauthCmds ) =
            MyOauth.init location

        model =
            Model
                route
                Material.model
                oauth
                game
                editor
                { name = Nothing }
                backend
                Types.Anonymous
                tableList
                0

        cmds =
            Cmd.batch <|
                List.concat
                    [ gameCmds
                    , [ hide "peekaboo"
                      , Cmd.map EditorMsg editorCmd
                      , backendCmd
                      ]
                    , oauthCmds
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

        GetToken res ->
            case res of
                Err err ->
                    let
                        oauth =
                            model.oauth

                        oauth_ =
                            { oauth | error = Just "unable to fetch user profile ¯\\_(ツ)_/¯" }
                    in
                        { model | oauth = oauth_ } ! []

                Ok token ->
                    let
                        backend =
                            model.backend

                        backend_ =
                            { backend | jwt = token }
                    in
                        { model | backend = backend_ }
                            ! [ auth [ token ]
                              , Backend.loadMe backend_
                              ]

        GetProfile res ->
            let
                oauth =
                    model.oauth

                backend =
                    model.backend
            in
                case res of
                    Err err ->
                        let
                            oauth_ =
                                { oauth | error = Just "unable to fetch user profile ¯\\_(ツ)_/¯" }
                        in
                            { model | oauth = oauth_ } ! []

                    Ok profile ->
                        { model | user = Logged profile } ! []

        Authorize ->
            MyOauth.authorize model

        LoadToken token ->
            let
                backend =
                    model.backend

                backend_ =
                    { backend | jwt = token }
            in
                { model | backend = backend_ }
                    ! [ Backend.loadMe backend_ ]

        Authenticate code ->
            model ! [ Backend.authenticate model.backend code ]

        Logout ->
            let
                backend =
                    model.backend

                backend_ =
                    { backend | jwt = "" }
            in
                { model | user = Anonymous, backend = backend_ }
                    ! [ auth [] ]

        NavigateTo route ->
            model ! [ navigateTo route ]

        DrawerNavigateTo route ->
            model ! msgsToCmds [ Layout.toggleDrawer Mdl, NavigateTo route ]

        OnLocationChange location ->
            let
                newRoute =
                    parseLocation location

                newModel =
                    { model | route = newRoute }
            in
                case newRoute of
                    GameRoute table ->
                        let
                            ( game, gameCmds ) =
                                Game.State.init (Just newModel) table
                        in
                            { newModel | game = game } ! gameCmds

                    _ ->
                        newModel ! []

        Mdl msg ->
            Material.update Mdl msg model

        ChangeTable table ->
            (Game.State.setter model (\g -> { g | table = table })) ! []

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
                --case boardMsg of
                --Board.Types.ClickLand land ->
                --Game.State.updateClickLand model_ land
                --! [ Cmd.map BoardMsg newBoardMsg ]
                --_ ->
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
            in
                model
                    ! [ Backend.Types.Chat (Types.getUsername model) model.game.chatInput
                            |> TableMsg model.game.table
                            |> Backend.publish
                      , Task.perform (always ClearChat) (Task.succeed ())
                      ]

        ClearChat ->
            let
                game =
                    model.game

                game_ =
                    { game | chatInput = "" }
            in
                { model | game = game_ } ! []

        GameCmd playerAction ->
            model ! [ Backend.gameCommand model.backend model.game.table playerAction ]

        GameCommandResponse table action (Ok response) ->
            Game.State.updateCommandResponse table action model

        GameCommandResponse table action (Err err) ->
            Backend.updateChatLog model <| Backend.Types.LogError <| Game.Chat.toChatError table action err

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
            model ! []

        TableMsg table msg ->
            if table == model.game.table then
                case msg of
                    Backend.Types.Join user ->
                        Backend.updateChatLog model <| Backend.Types.LogJoin user

                    Backend.Types.Leave user ->
                        Backend.updateChatLog model <| Backend.Types.LogLeave user

                    Backend.Types.Chat user text ->
                        Backend.updateChatLog model <| Backend.Types.LogChat user text

                    Backend.Types.Update status ->
                        Game.State.updateTableStatus model status
            else
                model ! []

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
        [ Layout.fixedHeader, Layout.scrolling ]
        { header = (lazyList header) model
        , drawer = (lazyList drawer) model
        , tabs = ( [], [] )
        , main = [ Html.div [ Html.Attributes.class "Main" ] [ mainView model ] ]
        }


header : Model -> List (Html.Html Msg)
header model =
    [ Layout.row
        [ Material.Options.cs "header" ]
        [ Layout.title [] [ Html.text "¡Qué Dice!" ]
        , Layout.spacer
        , Layout.navigation []
            [ Layout.link
                [ Material.Options.cs "header--profile-link"
                , Material.Options.onClick <|
                    case model.user of
                        Anonymous ->
                            Authorize

                        Logged _ ->
                            Logout
                ]
                (case model.user of
                    Logged user ->
                        [ Html.div [] [ Html.text <| user.name ]
                        , Html.img [ Html.Attributes.src user.picture ] []
                        ]

                    Anonymous ->
                        [ Icon.i "account_circle" ]
                )
            ]
        ]
    ]


drawer : Model -> List (Html.Html Msg)
drawer model =
    [ Layout.title [] [ Html.text "¡Qué Dice!" ]
    , Layout.navigation []
        (List.map
            (\( label, path ) ->
                Layout.link
                    [ {- Layout.href <| "#" ++ path, -} Material.Options.onClick <| DrawerNavigateTo path ]
                    [ Html.text label ]
            )
            [ ( "Play", GameRoute Melchor )
            , ( "Help", StaticPageRoute Help )
            , ( "My profile", MyProfileRoute )
            , ( "Editor (experimental)", EditorRoute )
            ]
        )
    ]


mainView : Model -> Html.Html Msg
mainView model =
    case model.route of
        GameRoute table ->
            Game.View.view model

        StaticPageRoute page ->
            Static.View.view model

        EditorRoute ->
            Editor.Editor.view model

        NotFoundRoute ->
            Html.text "404"

        MyProfileRoute ->
            case model.user of
                Anonymous ->
                    Html.text "404"

                Logged user ->
                    MyProfile.MyProfile.view model user


mainViewSubscriptions : Model -> Sub Msg
mainViewSubscriptions model =
    case model.route of
        -- EditorRoute ->
        --     Editor.Editor.subscriptions model.editor |> Sub.map EditorMsg
        _ ->
            Sub.none


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ mainViewSubscriptions model
        , Backend.subscriptions model
        , Time.every (666) Tick
        ]


port hide : String -> Cmd msg


port auth : List String -> Cmd msg
