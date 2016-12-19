module Game.Types exposing (..)

import Board exposing (Msg)
import Land exposing (Color)
import Tables exposing (Table)


type Msg
    = BoardMsg Board.Msg


type alias Model =
    { table : Table
    , board : Board.Model
    , players : List Player
    }


type alias Player =
    { name : PlayerName
    , color : Color
    }


type alias PlayerName =
    String
