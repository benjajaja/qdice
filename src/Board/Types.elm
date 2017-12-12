module Board.Types exposing (..)

import Land exposing (Map, Land)


type Msg
    = ClickLand Land
    | HoverLand Land
    | UnHoverLand Land


type alias Model =
    { map : Map
    , hovered : Maybe Land
    , move : BoardMove
    }


type BoardMove
    = Disabled
    | Idle
    | From Land
    | FromTo Land Land


type alias LandUpdate =
    { emoji : Land.Emoji
    , color : Land.Color
    , points : Int
    }
