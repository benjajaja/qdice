module Games.Types exposing (..)

import Dict exposing (Dict)
import Land exposing (Color, Emoji)
import Tables exposing (MapName, Table)
import Time exposing (Posix)


type alias GamesModel =
    { tables : Dict String (List Game)
    , all : List Game
    }


type alias Game =
    { id : Int
    , tag : Table
    , map : MapName
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
    | EndTurn Int (List ( Emoji, Int )) Int (List Emoji) ShortGamePlayer Bool
    | SitOut ShortGamePlayer
    | SitIn ShortGamePlayer
    | ToggleReady ShortGamePlayer Bool
    | Flag ShortGamePlayer Int
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
