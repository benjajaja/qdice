import Window
import Html
import Html.Events as Html
import Html.App as App
import String
import Dict
import Task

import Board
import Land

main : Program Never
main =
  App.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions --\_ -> Window.resizes sizeToMsg
    }


type Msg
  = Resize (Int, Int)
  | Board Board.Msg

type alias Model =
  { size: (Int, Int)
  , board: Board.Model
  }

init : (Model, Cmd Msg)
init =
  let
    (board, boardFx) = Board.init
  in
    (Model (0, 0) board
    , Cmd.batch [ Cmd.map Board boardFx
      , Task.perform (\a -> Debug.log "?" a) sizeToMsg Window.size
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

updateMap : Model -> Cmd Msg -> Land.Map -> (Model, Cmd Msg)    
updateMap model cmd map =
  let
    {board} = model
  in
    ({ model | board = { board | map = map } }, cmd)


view : Model -> Html.Html Msg
view model =
  let
    header = Html.h1 [] [Html.text "eDice"]
    board' = Board.view model.board
  in
    Html.div [] [
      header
      , App.map Board board'
    ]



subscriptions : Model -> Sub Msg
subscriptions model =
  Window.resizes sizeToMsg

sizeToMsg : Window.Size -> Msg
sizeToMsg size =
  Debug.log "size" (Resize (size.width, size.height))

