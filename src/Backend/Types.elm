module Backend.Types exposing (..)

import Http
import Tables exposing (Table(..))
import Game.Types exposing (TableStatus)


type Msg
    = Connected ClientId
    | StatusConnect String
    | StatusReconnect Int
    | StatusOffline String
    | Subscribed Topic
    | ClientMsg ClientMessage
    | AllClientsMsg AllClientsMessage
    | TableMsg Table TableMessage
    | UnknownTopicMessage String String String
    | JoinTable Table
    | Joined (Result Http.Error TableStatus)


type alias Model =
    { clientId : Maybe ClientId
    , subscribed : List Topic
    , status : ConnectionStatus
    , chatLog : List ChatLogEntry
    }


type ChatLogEntry
    = LogJoin User
    | LogLeave User
    | LogChat User String


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
    | Online


type ClientMessage
    = None


type AllClientsMessage
    = PresentYourself


type TableMessage
    = Join User
    | Chat User String
    | Leave User


type alias User =
    String
