module Games.Types exposing (..)

import Land exposing (Color)
import Tables exposing (Table)
import Time exposing (Posix)


type alias Game =
    { id : Int
    , tag : Table
    , gameStart : Posix
    , players : List GamePlayer
    }


type alias GamePlayer =
    { id : String
    , name : String
    , picture : String
    , color : Color
    }
