port module Edice exposing (..)

import Task
import Types exposing (..)
import Game.State
import Game.View
import Editor.Editor
import Html
import Html.Attributes
import Material
import Material.Layout as Layout
import Material.Icon as Icon
import Navigation
import UrlParser exposing ((</>))
import Hop
import Hop.Types exposing (Config, Address, Query)
import Backend
import Tables exposing (Table(..))


urlParser : Navigation.Parser ( Route, Address )
urlParser =
    let
        -- A parse function takes the normalised path from Hop after taking
        -- in consideration the basePath and the hash.
        -- This function then returns a result.
        parse path =
            -- First we parse using UrlParser.parse.
            -- Then we return the parsed route or NotFoundRoute if the parsed failed.
            -- You can choose to return the parse return directly.
            path
                |> UrlParser.parse identity routes
                |> Result.withDefault NotFoundRoute

        resolver =
            -- Create a function that parses and formats the URL
            -- This function takes 2 arguments: The Hop Config and the parse function.
            Hop.makeResolver hopConfig parse
    in
        -- Create a Navigation URL parser
        Navigation.makeParser (.href >> resolver)


hopConfig : Config
hopConfig =
    { hash = False
    , basePath = ""
    }


main : Program Never
main =
    Navigation.program urlParser
        { init = init
        , view = view
        , update = update
        , urlUpdate = urlUpdate
        , subscriptions =
            subscriptions
        }


init : ( Route, Address ) -> ( Model, Cmd Msg )
init ( route, address ) =
    let
        ( game, gameCmd ) =
            Game.State.init

        ( editor, editorCmd ) =
            Editor.Editor.init

        backend =
            Backend.init

        model =
            Model address route Material.model game editor backend Types.Anonymous

        _ =
            Debug.log "init" ( route, address )

        cmds =
            Cmd.batch
                [ urlUpdate ( route, address ) model |> snd
                , hide "peekaboo"
                , Cmd.map GameMsg gameCmd
                , Cmd.map EditorMsg editorCmd
                , Backend.connect
                ]
    in
        ( model
        , cmds
        )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GameMsg msg ->
            let
                ( model, gameCmd ) =
                    Game.State.update msg model
            in
                ( model, Cmd.map GameMsg gameCmd )

        EditorMsg msg ->
            let
                ( editor, editorCmd ) =
                    Editor.Editor.update msg model.editor
            in
                ( { model | editor = editor }, Cmd.map EditorMsg editorCmd )

        BckMsg msg ->
            let
                ( model, bckCmd ) =
                    Backend.update msg model
            in
                ( model, bckCmd )

        NavigateTo path ->
            let
                command =
                    -- First generate the URL using your config (`outputFromPath`).
                    -- Then generate a command using Navigation.newUrl.
                    Hop.outputFromPath hopConfig path
                        |> Navigation.newUrl
            in
                ( model, command )

        DrawerNavigateTo path ->
            model ! msgsToCmds [ Layout.toggleDrawer Mdl, NavigateTo path ]

        SetQuery query ->
            let
                command =
                    -- First modify the current stored address record (setting the query)
                    -- Then generate a URL using Hop.output
                    -- Finally, create a command using Navigation.newUrl
                    model.address
                        |> Hop.setQuery query
                        |> Hop.output hopConfig
                        |> Navigation.newUrl
            in
                ( model, command )

        Mdl msg ->
            Material.update msg model


msgsToCmds : List Msg -> List (Cmd Msg)
msgsToCmds msgs =
    List.map (\msg -> Task.perform (always msg) (always msg) (Task.succeed ())) msgs


urlUpdate : ( Route, Address ) -> Model -> ( Model, Cmd Msg )
urlUpdate ( route, address ) model =
    let
        cmd =
            case route of
                EditorRoute ->
                    snd Editor.Editor.init |> Cmd.map EditorMsg

                _ ->
                    Cmd.none
    in
        ( { model | route = route, address = address }, cmd )


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
        []
        [ Layout.title [] [ Html.text "¡Qué Dice!" ]
        , Layout.spacer
        , Layout.navigation []
            [ Layout.link
                [ Layout.href "javascript:window.location.reload()" ]
                [ Html.text <|
                    case model.user of
                        Logged user ->
                            user.name

                        Anonymous ->
                            "Anon"
                , Icon.i "profile"
                ]
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
                    [ {- Layout.href <| "#" ++ path, -} Layout.onClick <| DrawerNavigateTo path ]
                    [ Html.text label ]
            )
            [ ( "Play", "/" )
            , ( "Editor (experimental)", "/editor" )
            , ( "Table:Melchor (test)", "/Melchor" )
            ]
        )
    ]


mainView : Model -> Html.Html Msg
mainView model =
    case model.route of
        GameRoutes gameRoute ->
            Game.View.view model

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
        ]


routes : UrlParser.Parser (Route -> a) a
routes =
    UrlParser.oneOf
        [ UrlParser.format GameRoutes (UrlParser.oneOf gameMatchers)
        , UrlParser.format EditorRoute (UrlParser.s "editor")
        ]


gameMatchers : List (UrlParser.Parser (GameRoute -> a) a)
gameMatchers =
    [ UrlParser.format GameRoute (UrlParser.s "")
    , UrlParser.format (GameTableRoute Melchor) (UrlParser.s "Melchor")
    ]


port hide : String -> Cmd msg
