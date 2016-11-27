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
            --\_ -> Window.resizes sizeToMsg
        }


type Msg
    = Resize ( Int, Int )
    | NavigateTo String
    | SetQuery Query
    | Mdl (Material.Msg Msg)
    | BoardMsg Board.Types.Msg


type alias Model =
    { address : Address
    , route : Route
    , mdl : Material.Model
    , size : ( Int, Int )
    , board : Board.Types.Model
    }


type Route
    = GameRoute
    | EditorRoute
    | NotFoundRoute


init : ( Route, Address ) -> ( Model, Cmd Msg )
init ( route, address ) =
    let
        ( board, boardFx ) =
            Board.State.init
    in
        ( Model address route Material.model ( 0, 0 ) board
        , Cmd.batch
            [ Cmd.map BoardMsg boardFx
            , Task.perform (\a -> Debug.log "?" a) sizeToMsg Window.size
            , hide "?"
            ]
        )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    let
        { size, board } =
            model
    in
        case msg of
            Resize size ->
                ( { model | board = { board | size = size } }, Cmd.none )

            BoardMsg msg ->
                let
                    ( board, boardCmds ) =
                        Board.State.update msg board
                in
                    ( { model | board = board }, Cmd.map BoardMsg boardCmds )

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

            Mdl msg' ->
                Material.update msg' model


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
            Html.div [] [ Html.text "game" ]

        EditorRoute ->
            App.map BoardMsg (Editor.view model.board)

        -- App.map Board (Board.view model.board)
        NotFoundRoute ->
            Html.text "404"


subscriptions : Model -> Sub Msg
subscriptions model =
    Window.resizes sizeToMsg


routes : UrlParser.Parser (Route -> a) a
routes =
    UrlParser.oneOf
        [ UrlParser.format GameRoute (UrlParser.s "")
        , UrlParser.format EditorRoute (UrlParser.s "editor")
        ]


sizeToMsg : Window.Size -> Msg
sizeToMsg size =
    Debug.log "size" (Resize ( size.width, size.height ))


port hide : String -> Cmd msg
