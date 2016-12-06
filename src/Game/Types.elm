module Game.Types exposing (..)

import Material
import Board
import Land exposing (Land)


type Msg
    = Mdl (Material.Msg Msg)
    | BoardMsg Board.Msg


type alias Model =
    { board : Board.Model
    }
