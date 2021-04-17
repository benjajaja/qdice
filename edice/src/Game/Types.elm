module Game.Types exposing (Award, ChatLogEntry(..), Chatter, Elimination, EliminationReason(..), GameStatus(..), MapLoadError(..), Model, Move, Msg(..), Player, PlayerAction(..), PlayerGameStats, PlayerId, PlayerName, Roll, RollLog, RollPart, RollUI, TableInfo, TableParams, TableStatus, TournamentConfig, TurnInfo, User, actionToString, isBot, makePlayer, statusToString, userColor)

import Board
import Browser.Dom as Dom
import Land exposing (Color, DiceSkin(..), Emoji, LandUpdate)
import LeaderBoard.ChartTypes exposing (Datum)
import Tables exposing (Table)
import Time exposing (Posix)


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
    | Flag Int
    | ToggleReady Bool
    | Heartbeat


type Msg
    = ScrollChat String (List ChatLogEntry) (Result Dom.Error Dom.Viewport)
    | ToggleDiceVisible Bool
    | Hint (Maybe Datum)


type alias Model =
    { table : Maybe Table
    , board : Board.Model
    , boardOptions : Board.BoardOptions
    , hovered : Maybe Land.Emoji
    , players : List Player
    , player : Maybe Player
    , status : GameStatus
    , gameStart : Maybe Int
    , playerSlots : Int
    , startSlots : Int
    , points : Int
    , turnIndex : Int
    , hasTurn : Bool
    , canMove : Bool
    , turnStart : Int
    , chatInput : String
    , chatLog : List ChatLogEntry
    , gameLog : List ChatLogEntry
    , chatOverlay : Maybe ( Posix, ChatLogEntry )
    , isPlayerOut : Bool
    , roundCount : Int
    , isReady : Maybe Bool
    , flag : Maybe Int
    , params : TableParams
    , currentGame : Maybe Int
    , expandChat : Bool
    , lastRoll : Maybe RollUI
    , chartHinted : Maybe Datum
    }


type alias Player =
    { id : PlayerId
    , name : PlayerName
    , color : Color
    , picture : String
    , out : Maybe Int
    , gameStats : PlayerGameStats
    , reserveDice : Int
    , points : Int
    , level : Int
    , awards : List Award
    , flag : Maybe Int
    , ready : Bool
    , skin : DiceSkin
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
    , mapName : Tables.MapName
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


type alias RollUI =
    { from : ( Color, List Int )
    , to : ( Color, List Int )
    , rolling : Maybe Posix
    , timestamp : Posix
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
    , mapName : Tables.MapName
    , playerSlots : Int
    , startSlots : Int
    , playerCount : Int
    , watchCount : Int
    , botCount : Int
    , status : GameStatus
    , landCount : Int
    , stackSize : Int
    , points : Int
    , params : TableParams
    , gameStart : Maybe Int
    }


type alias TableParams =
    { noFlagRounds : Int
    , botLess : Bool
    , startingCapitals : Bool
    , readySlots : Maybe Int
    , turnSeconds : Maybe Int
    , twitter : Bool
    , tournament : Maybe TournamentConfig
    }


type alias TournamentConfig =
    { frequency : String
    , prize : Int
    , fee : Int
    }


type alias Move =
    { from : Emoji
    , to : Emoji
    }


type alias User =
    -- TODO replace with Chatter
    String


type alias Chatter =
    { name : String
    , color : Maybe Color
    }


type ChatLogEntry
    = LogEnter (Maybe User)
    | LogExit (Maybe User)
    | LogChat (Maybe Chatter) String
    | LogJoin Player
    | LogLeave Player
    | LogTakeover Player Player
    | LogError String
    | LogRoll RollLog
    | LogTurn User Color
    | LogElimination User Color Int Int EliminationReason
    | LogBegin Table
    | LogReceiveDice Player Int
    | LogEndGame Table Int


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
    , steal : Maybe Int
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
    | ReasonFlag Int (Maybe ( Player, Int ))


type alias Award =
    { type_ : String
    , position : Int
    , timestamp : String
    , table : Maybe String
    }


type alias TurnInfo =
    { turnIndex : Int
    , turnStart : Int
    , roundCount : Int
    , giveDice : Maybe ( Player, Int )
    , players : List Player
    , lands : List LandUpdate
    }


type MapLoadError
    = NoTableNoMapError
    | BadTableError
    | MapLoadError String


makePlayer : String -> Player
makePlayer name =
    { id = ""
    , name = name
    , picture = ""
    , color = Land.Neutral
    , out = Nothing
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
    , skin = Normal
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
