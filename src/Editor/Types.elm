module Editor.Types exposing (..)

import Board
import Land exposing (Land)


type Msg
    = BoardMsg Board.Msg


type alias Model =
    { board : Board.Model
    , selectedLands : List Land
    }
