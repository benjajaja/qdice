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
    | SitIn
    | Attack Emoji Emoji
    | EndTurn


type alias Model =
    { table : Table
    , board : Board.Model
    , players : List Player
    , player : Maybe Player
    , status : GameStatus
    , gameStart : Maybe Int
    , playerSlots : Int
    , turnIndex : Int
    , hasTurn : Bool
    , turnStarted : Int
    , chatInput : String
    , chatLog : List ChatLogEntry
    , gameLog : List ChatLogEntry
    }


type alias Player =
    { id : PlayerId
    , name : PlayerName
    , color : Color
    , picture : String
    , out : Bool
    , gameStats : PlayerGameStats
    , reserveDice : Int
    , points : Int
    , level : Int
    }


type alias PlayerGameStats =
    { totalLands : Int
    , connectedLands : Int
    , currentDice : Int
    , position : Int
    , score : Int
    }


type alias PlayerId =
    String


type alias PlayerName =
    String


type alias TableStatus =
    { players : List Player
    , playerSlots : Int
    , status : GameStatus
    , gameStart : Int
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


type alias TableInfo =
    { table : Table
    , playerSlots : Int
    , playerCount : Int
    , status : GameStatus
    , landCount : Int
    , stackSize : Int
    }


type alias Move =
    { from : Emoji
    , to : Emoji
    }


type alias User =
    String


type ChatLogEntry
    = LogJoin User
    | LogLeave User
    | LogChat User String
    | LogError String
    | LogRoll RollLog
    | LogTurn User Color
    | LogElimination User Color Int EliminationReason
    | LogBegin Table


type alias RollLog =
    { attacker : User
    , defender : User
    , attackRoll : Int
    , attackDiesEmojis : String
    , defendDiesEmojis : String
    , defendRoll : Int
    , success : Bool
    }


type alias Elimination =
    { player : Player
    , position : Int
    , reason : EliminationReason
    }


type alias EliminationReason =
    { eliminationType :
        EliminationType
        --, source : String
    }


type EliminationType
    = Death
    | Out
    | Win


makePlayer : String -> Player
makePlayer name =
    { id = ""
    , name = name
    , picture = ""
    , color = Land.Neutral
    , out = False
    , points = 0
    , level = 0
    , gameStats =
        { totalLands = 0
        , connectedLands = 0
        , currentDice = 0
        , position = 0
        , score = 0
        }
    , reserveDice = 0
    }
