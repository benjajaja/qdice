module Editor.Types exposing (..)

import Material
import Board
import Land exposing (Land)


type Msg
    = Mdl (Material.Msg Msg)
    | BoardMsg Board.Msg
    | ClickAdd
    | RandomLandColor Land.Land Land.Color
    | ClickOutput String


type alias Model =
    { mdl : Material.Model
    , board : Board.Model
    , selectedLands : List Land
    , mapSave : List (List Char)
    }
