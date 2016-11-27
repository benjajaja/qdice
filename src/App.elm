port module Edice exposing (..)

import Editor
import Board.Types
import Board.State
import Window
import Html
import Html.App as App
import Task
import Material
import Material.Scheme
import Material.Layout as Layout
import Material.Icon as Icon
import Material.Button
import Navigation
import UrlParser exposing ((</>))
import Hop
import Hop.Types exposing (Config, Address, Query)


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
    { hash = True
    , basePath = "edice"
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


type Msg
    = NavigateTo String
    | SetQuery Query
    | Mdl (Material.Msg Msg)
    | EditorMsg Editor.Msg


type alias Model =
    { address : Address
    , route : Route
    , mdl : Material.Model
    , editor : Editor.Model
    }


type Route
    = GameRoute
    | EditorRoute
    | NotFoundRoute


init : ( Route, Address ) -> ( Model, Cmd Msg )
init ( route, address ) =
    let
        ( model, cmd ) =
            Editor.init
    in
        ( Model address route Material.model model
        , Cmd.batch
            [ Cmd.map EditorMsg cmd
            , hide ""
            ]
        )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        EditorMsg msg ->
            let
                ( editor, editorCmd ) =
                    Editor.update msg model.editor
            in
                ( { model | editor = editor }, Cmd.map EditorMsg editorCmd )

        NavigateTo path ->
            let
                command =
                    -- First generate the URL using your config (`outputFromPath`).
                    -- Then generate a command using Navigation.newUrl.
                    Hop.outputFromPath hopConfig path
                        |> Navigation.newUrl
            in
                ( model, command )

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


urlUpdate : ( Route, Address ) -> Model -> ( Model, Cmd Msg )
urlUpdate ( route, address ) model =
    ( { model | route = route, address = address }, Cmd.none )


type alias Mdl =
    Material.Model


view : Model -> Html.Html Msg
view model =
    Layout.render Mdl
        model.mdl
        [ Layout.fixedHeader, Layout.scrolling ]
        { header = header
        , drawer = drawer model
        , tabs = ( [], [] )
        , main = [ mainView model ]
        }
        |> Material.Scheme.top


header : List (Html.Html Msg)
header =
    [ Layout.row
        []
        [ Layout.title [] [ Html.text "elm-dice" ]
        , Layout.spacer
        , Layout.navigation []
            [ Layout.link
                [ Layout.href "javascript:window.location.reload()" ]
                [ Icon.i "refresh" ]
              -- , Layout.link
              --     [ Layout.href "http://package.elm-lang.org/packages/debois/elm-mdl/latest/" ]
              --     [ Html.text "elm-package" ]
            ]
        ]
    ]


drawer : Model -> List (Html.Html Msg)
drawer model =
    [ Material.Button.render Mdl [ 0 ] model.mdl [ Material.Button.onClick (NavigateTo "") ] [ Html.text "Play" ]
    , Material.Button.render Mdl [ 0 ] model.mdl [ Material.Button.onClick (NavigateTo "editor") ] [ Html.text "Editor" ]
    ]


mainView : Model -> Html.Html Msg
mainView model =
    case model.route of
        GameRoute ->
            Html.div [] [ Html.text "Game!" ]

        EditorRoute ->
            App.map EditorMsg (Editor.view model.editor)

        -- App.map Board (Board.view model.board)
        NotFoundRoute ->
            Html.text "404"


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch
        [ Editor.subscriptions model.editor |> Sub.map EditorMsg
        ]


routes : UrlParser.Parser (Route -> a) a
routes =
    UrlParser.oneOf
        [ UrlParser.format GameRoute (UrlParser.s "")
        , UrlParser.format EditorRoute (UrlParser.s "editor")
        ]


port hide : String -> Cmd msg
