module Board.Types exposing (..)

import Land exposing (Map, Land)


type Msg
    = ClickLand Land
    | HoverLand Land
    | UnHoverLand Land


type alias Model =
    { map : Map
    }
