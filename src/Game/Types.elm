module Game.Types exposing (..)

import Board exposing (Msg, LandUpdate)
import Land exposing (Color)
import Tables exposing (Table)


type GameStatus
    = Paused
    | Playing
    | Finished


type PlayerAction
    = Enter
    | Join
    | Leave
    | SitOut


type alias Model =
    { table : Table
    , board : Board.Model
    , players : List Player
    , player : Maybe Player
    , status : GameStatus
    , playerSlots : Int
    , turnDuration : Int
    , turnIndex : Int
    , turnStarted : Int
    , chatInput : String
    , chatBoxId : String
    }


type alias Player =
    { id : PlayerId
    , name : PlayerName
    , color : Color
    , picture : String
    }


type alias PlayerId =
    String


type alias PlayerName =
    String


type alias TableStatus =
    { players : List Player
    , playerSlots : Int
    , status : GameStatus
    , turnIndex : Int
    , turnStarted : Int
    , lands : List LandUpdate
    }
