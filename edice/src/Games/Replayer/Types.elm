module Games.Replayer.Types exposing (..)

import Board
import Games.Types exposing (Game, GamePlayer)
import Time exposing (Posix)


type alias ReplayerModel =
    { board : Board.Model
    , boardOptions : Board.BoardOptions
    , players : List GamePlayer
    , turnIndex : Int
    , game : Game
    , step : Int
    , playing : Bool
    }


type ReplayerCmd
    = StepOne
    | StepN (Maybe Int)
    | TogglePlay
    | Tick Posix
