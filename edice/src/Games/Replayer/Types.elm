module Games.Replayer.Types exposing (..)

import Board
import Game.Types exposing (Player)
import Games.Types exposing (Game)
import Land exposing (Color)
import Time exposing (Posix)


type alias ReplayerModel =
    { board : Board.Model
    , boardOptions : Board.BoardOptions
    , players : List Player
    , avatarUrls : List ( Color, String )
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
