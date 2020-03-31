module Game.Types exposing (Award, ChatLogEntry(..), Elimination, EliminationReason(..), GameStatus(..), Model, Move, Msg(..), Player, PlayerAction(..), PlayerGameStats, PlayerId, PlayerName, Roll, RollLog, RollPart, TableInfo, TableParams, TableStatus, User, actionToString, isBot, makePlayer, statusToIcon, statusToString, userColor)

import Board exposing (LandUpdate)
import Browser.Dom as Dom
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
    | Flag Bool
    | ToggleReady Bool
    | Heartbeat


type Msg
    = ScrollChat String ChatLogEntry (Result Dom.Error Dom.Viewport)
    | ToggleDiceVisible Bool


type alias Model =
    { table : Maybe Table
    , board : Board.Model
    , players : List Player
    , player : Maybe Player
    , status : GameStatus
    , gameStart : Maybe Int
    , playerSlots : Int
    , startSlots : Int
    , points : Int
    , turnIndex : Int
    , hasTurn : Bool
    , turnStart : Int
    , chatInput : String
    , chatLog : List ChatLogEntry
    , gameLog : List ChatLogEntry
    , isPlayerOut : Bool
    , playerPosition : Int
    , roundCount : Int
    , canFlag : Bool
    , isReady : Maybe Bool
    , flag : Maybe Bool
    , params : TableParams
    , currentGame : Maybe Int
    , diceVisible : Bool
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
    , awards : List Award
    , flag : Maybe Int
    , ready : Bool
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
    , watchCount : Int
    , currentGame : Maybe Int
    }


type alias Roll =
    { from : RollPart
    , to : RollPart
    , turnStart : Int
    , players : List Player
    }


type alias RollPart =
    { emoji : Land.Emoji
    , roll : List Int
    }


type alias TableInfo =
    { table : Table
    , mapName : Tables.Map
    , playerSlots : Int
    , startSlots : Int
    , playerCount : Int
    , watchCount : Int
    , status : GameStatus
    , landCount : Int
    , stackSize : Int
    , points : Int
    , params : TableParams
    }


type alias TableParams =
    { noFlagRounds : Int
    , botLess : Bool
    }


type alias Move =
    { from : Emoji
    , to : Emoji
    }


type alias User =
    String


type ChatLogEntry
    = LogEnter (Maybe User)
    | LogExit (Maybe User)
    | LogChat (Maybe User) Color String
    | LogJoin Player
    | LogLeave Player
    | LogError String
    | LogRoll RollLog
    | LogTurn User Color
    | LogElimination User Color Int Int EliminationReason
    | LogBegin Table
    | LogReceiveDice Player Int


type alias RollLog =
    { attacker : User
    , attackerColor : Color
    , defenderColor : Color
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


type alias Award =
    { type_ : String
    , position : Int
    , timestamp : String
    }


makePlayer : String -> Player
makePlayer name =
    { id = ""
    , name = name
    , picture = ""
    , color = Land.Neutral
    , out = False
    , points = 0
    , level = 0
    , awards = []
    , gameStats =
        { totalLands = 0
        , connectedLands = 0
        , currentDice = 0
        , position = 0
        , score = 0
        }
    , reserveDice = 0
    , flag = Nothing
    , ready = False
    }


statusToString : GameStatus -> String
statusToString status =
    case status of
        Paused ->
            "paused"

        Playing ->
            "playing"

        Finished ->
            "finished"


statusToIcon : GameStatus -> String
statusToIcon status =
    case status of
        Paused ->
            "schedule"

        Playing ->
            "play_arrow"

        Finished ->
            "snooze"


actionToString : PlayerAction -> String
actionToString action =
    case action of
        Attack _ _ ->
            "Attack"

        Enter ->
            "Enter"

        Exit ->
            "Exit"

        Join ->
            "Join"

        Leave ->
            "Leave"

        Chat _ ->
            "Chat"

        SitOut ->
            "SitOut"

        SitIn ->
            "SitIn"

        EndTurn ->
            "EndTurn"

        Flag _ ->
            "Flag"

        ToggleReady _ ->
            "ToggleReady"

        Heartbeat ->
            "Heartbeat"


isBot : Player -> Bool
isBot =
    .id >> String.startsWith "bot_"


userColor : List Player -> String -> Land.Color
userColor players name =
    players
        |> List.filter (\p -> p.name == name)
        |> List.head
        |> Maybe.map .color
        |> Maybe.withDefault Land.Black
