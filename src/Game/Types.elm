module Game.Types exposing (..)

import Board exposing (Msg, LandUpdate)
import Land exposing (Color, Emoji)
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
    | Attack Emoji Emoji


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


type alias Roll =
    { from : RollPart
    , to : RollPart
    }


type alias RollPart =
    { emoji : Land.Emoji, roll : List Int }
