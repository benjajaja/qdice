port module Edice exposing (..)
import Window
import Html
import Html.Events as Html
import Html.Attributes as Html
import Html.App as App
import Task

import Navigation
import UrlParser exposing ((</>))
import Hop
import Hop.Types exposing (Config, Address, Query)

import HomepageCss
import SharedStyles
import Board
import Land

css = SharedStyles.homepageNamespace
-- { id, class, classList } = SharedStyles.homepageNamespace

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
    , subscriptions = subscriptions --\_ -> Window.resizes sizeToMsg
    }


type Msg
  = Resize (Int, Int)
  | NavigateTo String
  | SetQuery Query
  | Board Board.Msg

type alias Model =
  { address : Address
  , route: Route
  , size: (Int, Int)
  , board: Board.Model
  }

type Route
  = GameRoute
  | EditorRoute
  | NotFoundRoute

init : (Route, Address) ->  (Model, Cmd Msg)
init (route, address) =
  let
    (board, boardFx) = Board.init
  in
    (Model address route (0, 0) board
    , Cmd.batch [
      Cmd.map Board boardFx, Task.perform (\a -> Debug.log "?" a) sizeToMsg Window.size
      , hide "?"
      ]
    )

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  let
    {size, board} = model
  in
    case msg of
      Resize size ->
        ({ model | board = { board | size = size } }, Cmd.none)
      Board msg ->
        let
          (board, boardCmds) = Board.update msg board
        in
          ({ model | board = board }, Cmd.map Board boardCmds)
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

urlUpdate : ( Route, Address ) -> Model -> ( Model, Cmd Msg )
urlUpdate ( route, address ) model =
    ( { model | route = route, address = address }, Cmd.none )

updateMap : Model -> Cmd Msg -> Land.Map -> (Model, Cmd Msg)    
updateMap model cmd map =
  let
    {board} = model
  in
    ({ model | board = { board | map = map } }, cmd)


view : Model -> Html.Html Msg
view model = 
  Html.div [css.id SharedStyles.Root] [
    (Html.h1 [css.id SharedStyles.Logo] [Html.text "eDice"])
    , App.map Board (Board.view model.board)
    , (Html.button [Html.class "mui-button", Html.onClick (NavigateTo "editor")] [Html.text "Editor"])
    , (Html.div [] [Html.text (
      case model.route of
        GameRoute -> "Game"
        EditorRoute -> "Editor"
        NotFoundRoute -> "404"
    )])
  ]



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
  Debug.log "size" (Resize (size.width, size.height))

port hide : String -> Cmd msg