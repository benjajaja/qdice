module Backend.Types exposing (..)

import Tables exposing (Table)
import Game.Types


type alias Model =
    { baseUrl : String
    , jwt : String
    , clientId : Maybe ClientId
    , subscribed : List Topic
    , status : ConnectionStatus
    , chatLog : List ChatLogEntry
    }


type ChatLogEntry
    = LogJoin User
    | LogLeave User
    | LogChat User String
    | LogError String
    | LogRoll RollLog


type alias ClientId =
    String


type Topic
    = Client ClientId
    | AllClients
    | Presence
    | Tables Table TopicDirection


type TopicDirection
    = ClientDirection
    | ServerDirection
    | Broadcast


type ConnectionStatus
    = Offline
    | Connecting
    | Reconnecting Int
    | Subscribing
    | Online


type ClientMessage
    = None


type AllClientsMessage
    = PresentYourself


type TableMessage
    = Join User
    | Chat User String
    | Leave User
    | Update Game.Types.TableStatus
    | Roll Game.Types.Roll


type alias User =
    String


type alias RollLog =
    { attacker : User
    , defender : User
    , attackRoll : Int
    , attackDiesEmojis : String
    , defendDiesEmojis : String
    , defendRoll : Int
    , success : Bool
    }
