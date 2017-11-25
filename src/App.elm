port module Edice exposing (..)

import Task
import Maybe
import Navigation exposing (Location)
import Routing exposing (parseLocation, navigateTo)
import Types exposing (..)
import Game.State
import Game.View
import Board
import Static.View
import Editor.Editor
import Html
import Html.Lazy
import Html.Attributes
import Material
import Material.Layout as Layout
import Material.Icon as Icon
import Material.Options
import Backend
import Backend.Types
import Tables exposing (Table(..), tableList)


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
            Backend.init table

        model =
            Model route Material.model game editor backend Types.Anonymous tableList

        cmds =
            Cmd.batch <|
                List.append
                    gameCmds
                    [ hide "peekaboo"
                    , Cmd.map EditorMsg editorCmd
                    , Cmd.map BckMsg backendCmd
                      -- , Backend.connect
                    ]
    in
        ( model
        , cmds
        )


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
        EditorMsg msg ->
            let
                ( editor, editorCmd ) =
                    Editor.Editor.update msg model.editor
            in
                ( { model | editor = editor }, Cmd.map EditorMsg editorCmd )

        BckMsg msg ->
            Backend.update msg model

        LoggedIn data ->
            case data of
                [ email, name, picture ] ->
                    let
                        user =
                            Logged
                                { email = email
                                , name = name
                                , picture = picture
                                }
                    in
                        { model | user = user } ! [ Cmd.map BckMsg <| Backend.joinTable user model.game.table ]

                _ ->
                    model ! []

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

                ( board, boardCmd ) =
                    Board.update boardMsg model.game.board

                game_ =
                    { game | board = board }
            in
                { model | game = game_ } ! [ Cmd.map BoardMsg boardCmd ]

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
                            |> Backend.Types.TableMsg model.game.table
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

        JoinGame ->
            model
                ! []


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
                [ Layout.href "javascript:window.login()"
                , Material.Options.cs "header--profile-link"
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
            , ( "Table:Melchor", GameRoute Melchor )
            , ( "Table:Miño", GameRoute Miño )
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
        , onLogin LoggedIn
        ]


port hide : String -> Cmd msg


port onLogin : (List String -> msg) -> Sub msg
