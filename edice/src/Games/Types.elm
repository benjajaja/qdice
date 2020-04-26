module Games.Types exposing (..)

import Land exposing (Color, Emoji)
import Tables exposing (Table)
import Time exposing (Posix)


type alias Game =
    { id : Int
    , tag : Table
    , gameStart : Posix
    , players : List GamePlayer
    , events : List GameEvent
    , lands : List Land.LandUpdate
    }


type alias GameRef =
    { id : Int
    , tag : Table
    , gameStart : Posix
    }


type GameEvent
    = Start
    | Chat ShortGamePlayer String
    | Attack ShortGamePlayer Emoji Emoji
    | Roll (List Int) (List Int)
    | EndTurn Int ShortGamePlayer
    | TickTurnOut
    | TickTurnOver Bool
    | SitOut ShortGamePlayer
    | SitIn ShortGamePlayer
    | ToggleReady ShortGamePlayer Bool
    | Flag ShortGamePlayer
    | EndGame (Maybe ShortGamePlayer) Int
    | Unknown String


type alias ShortGamePlayer =
    { id : String
    , name : String
    }


type alias GamePlayer =
    { id : String
    , name : String
    , picture : String
    , color : Color
    , isBot : Bool
    }
