module Board.Types exposing (..)

import Land exposing (Map, Land)


type Msg
    = WindowResize ( Int, Int )
    | Resize Int
    | ClickLand Land
    | HoverLand Land
    | UnHoverLand Land


type alias Model =
    { width : Int
    , map : Map
    }
