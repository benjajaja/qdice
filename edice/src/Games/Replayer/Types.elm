module Games.Replayer.Types exposing (..)

import Board.Types
import Game.Types exposing (Player)
import Games.Types exposing (Game)
import Time exposing (Posix)


type alias ReplayerModel =
    { board : Board.Types.Model
    , players : List Player
    , turnIndex : Int
    , game : Game
    , step : Int
    , round : Int
    , playing : Bool
    , log : List ReplayerLogLine
    }


type alias ReplayerLogLine =
    List ReplayerLogPart


type ReplayerLogPart
    = LogPlayer Player
    | LogNeutralPlayer
    | LogString String
    | LogError String


type ReplayerCmd
    = StepOne
    | StepN (Maybe Int)
    | TogglePlay
    | Tick Posix
