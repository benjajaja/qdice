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
    | Exit
    | Join
    | Leave
    | Chat String
    | SitOut
    | SitIn
    | Attack Emoji Emoji
    | EndTurn
    | Flag
    | Heartbeat


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
    , turnStart : Int
    , chatInput : String
    , chatLog : List ChatLogEntry
    , gameLog : List ChatLogEntry
    , isPlayerOut : Bool
    , roundCount : Int
    , canFlag : Bool
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
    , flag : Maybe Int
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
    , mapName : Tables.Map
    , playerSlots : Int
    , status : GameStatus
    , gameStart : Int
    , turnIndex : Int
    , turnStart : Int
    , lands : List LandUpdate
    , roundCount : Int
    , canFlag : Bool
    , watchCount : Int
    }


type alias Roll =
    { from : RollPart
    , to : RollPart
    }


type alias RollPart =
    { emoji : Land.Emoji, roll : List Int }


type alias TableInfo =
    { table : Table
    , mapName : Tables.Map
    , playerSlots : Int
    , playerCount : Int
    , watchCount : Int
    , status : GameStatus
    , landCount : Int
    , stackSize : Int
    , points : Int
    }


type alias Move =
    { from : Emoji
    , to : Emoji
    }


type alias User =
    String


type ChatLogEntry
    = LogJoin (Maybe User)
    | LogLeave (Maybe User)
    | LogChat (Maybe User) Color String
    | LogError String
    | LogRoll RollLog
    | LogTurn User Color
    | LogElimination User Color Int Int EliminationReason
    | LogBegin Table


type alias RollLog =
    { attacker : User
    , defender : User
    , attackRoll : Int
    , attackDiesEmojis : String
    , attackDiceCount : Int
    , defendDiesEmojis : String
    , defendRoll : Int
    , defendDiceCount : Int
    , success : Bool
    }


type alias Elimination =
    { player : Player
    , position : Int
    , score : Int
    , reason : EliminationReason
    }


type EliminationReason
    = ReasonDeath Player Int
    | ReasonOut Int
    | ReasonWin Int
    | ReasonFlag Int


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
    , flag = Nothing
    }
