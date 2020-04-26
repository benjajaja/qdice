module Games.Replayer.Types exposing (..)

import Board
import Game.Types exposing (Player)
import Games.Types exposing (Game)


type alias ReplayerModel =
    { board : Board.Model
    , boardOptions : Board.BoardOptions
    , players : List Player
    , game : Game
    , step : Int
    , playing : Bool
    }


type ReplayerCmd
    = StepOne
    | TogglePlay
