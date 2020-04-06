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
    , lands : List ( Emoji, Color, Int )
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
    | EndTurn ShortGamePlayer
    | TickTurnOut
    | TickTurnOver Bool
    | TickTurnAllOut
    | SitOut ShortGamePlayer
    | SitIn ShortGamePlayer
    | ToggleReady ShortGamePlayer Bool
    | Flag ShortGamePlayer
    | EndGame (Maybe ShortGamePlayer) Int


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
