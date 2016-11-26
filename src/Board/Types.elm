module Board.Types exposing (..)

import Land exposing (Map, Land)


type Msg
    = Resize ( Int, Int )
    | ClickLand Land
    | HoverLand Land
    | UnHoverLand Land


type alias Model =
    { size : ( Int, Int )
    , map : Map
    }
