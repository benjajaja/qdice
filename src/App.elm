port module Edice exposing (..)

import Task
import Maybe
import Navigation exposing (Location)
import Routing exposing (parseLocation, navigateTo)
import Helpers exposing (..)
import Types exposing (..)
import Game.State
import Game.View
import Static.View
import Editor.Editor
import Html
import Html.Attributes
import Material
import Material.Layout as Layout
import Material.Icon as Icon
import Material.Options
import UrlParser exposing ((</>))
import Backend
import Tables exposing (Table(..))


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

        ( game, gameCmd ) =
            Game.State.init <| Maybe.withDefault Melchor <| currentTable route

        ( editor, editorCmd ) =
            Editor.Editor.init

        backend =
            Backend.init

        model =
            Model route Material.model game editor backend Types.Anonymous

        -- newRoute =
        --     case route of
        --         GameRoute table ->
        --             let
        --                 _ =
        --                     Debug.log "GameRoute r" r
        --             in
        --                 GameRoutes <| GameTableRoute Melchor
        --         _ ->
        --             route
        _ =
            Debug.log "init" ( route, location )

        cmds =
            Cmd.batch
                [ hide "peekaboo"
                , Cmd.map GameMsg gameCmd
                , Cmd.map EditorMsg editorCmd
                , Backend.connect
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

        -- _ =
        --     Debug.log "update" msg
    in
        ( model_, cmd )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GameMsg msg ->
            let
                ( newModel, gameCmd ) =
                    Game.State.update msg model
            in
                ( newModel, Cmd.map GameMsg gameCmd )

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

                        _ =
                            Debug.log "login" user
                    in
                        { model | user = user } ! []

                _ ->
                    model ! []

        NavigateTo route ->
            model ! [ navigateTo route ]

        DrawerNavigateTo route ->
            model ! msgsToCmds [ Layout.toggleDrawer Mdl, NavigateTo route ]

        OnLocationChange location ->
            let
                newRoute =
                    Debug.log "newRoute" <| parseLocation location

                newModel =
                    { model | route = newRoute }
            in
                case newRoute of
                    GameRoute table ->
                        let
                            ( game, gameCmd ) =
                                Game.State.init table
                        in
                            { newModel | game = game } ! [ Cmd.map GameMsg gameCmd ]

                    _ ->
                        newModel ! []

        -- SetQuery query ->
        --     let
        --         command =
        --             -- First modify the current stored address record (setting the query)
        --             -- Then generate a URL using Hop.output
        --             -- Finally, create a command using Navigation.newUrl
        --             model.address
        --                 |> Hop.setQuery query
        --                 |> Hop.output hopConfig
        --                 |> Navigation.newUrl
        --     in
        --         ( model, command )
        Mdl msg ->
            Material.update Mdl msg model


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



-- urlUpdate : ( Route, Address ) -> Model -> ( Model, Cmd Msg )
-- urlUpdate ( route, address ) model =
--     let
--         cmd =
--             case route of
--                 EditorRoute ->
--                     Tuple.second Editor.Editor.init |> Cmd.map EditorMsg
--                 _ ->
--                     Cmd.none
--     in
--         ( { model | route = route, address = address }, cmd )


type alias Mdl =
    Material.Model


view : Model -> Html.Html Msg
view model =
    Layout.render Mdl
        model.mdl
        [ Layout.fixedHeader, Layout.scrolling ]
        { header = header model
        , drawer = drawer model
        , tabs = ( [], [] )
        , main = [ Html.div [ Html.Attributes.class "Main" ] [ mainView model ] ]
        }



-- |> Material.Scheme.top


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
              -- , Layout.link
              --     [ Layout.href "http://package.elm-lang.org/packages/debois/elm-mdl/latest/" ]
              --     [ Html.text "elm-package" ]
            ]
        ]
    ]


drawer : Model -> List (Html.Html Msg)
drawer model =
    [ Layout.title [] [ Html.text "Elm Dice" ]
    , Layout.navigation []
        (List.map
            (\( label, path ) ->
                Layout.link
                    [ {- Layout.href <| "#" ++ path, -} Material.Options.onClick <| DrawerNavigateTo path ]
                    [ Html.text label ]
            )
            [ ( "Play", GameRoute Melchor )
            , ( "Help", StaticPageRoute Help )
            , ( "Editor (experimental)", EditorRoute )
            , ( "Table:Melchor (test)", GameRoute Melchor )
            , ( "Table:Miño", GameRoute Miño )
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
