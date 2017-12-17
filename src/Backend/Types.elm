module Backend.Types exposing (..)

import Tables exposing (Table)
import Game.Types


type alias Model =
    { baseUrl : String
    , jwt : String
    , clientId : Maybe ClientId
    , subscribed : List Topic
    , status : ConnectionStatus
    }


type alias ClientId =
    String


type Topic
    = Client ClientId
    | AllClients
    | Tables Table TopicDirection


type TopicDirection
    = ClientDirection
    | ServerDirection
    | Broadcast


type ConnectionStatus
    = Offline
    | Connecting
    | Reconnecting Int
    | SubscribingGeneral
    | SubscribingTable
    | Online


type ClientMessage
    = None


type AllClientsMessage
    = TablesInfo (List Game.Types.TableInfo)


type alias User =
    String


type TableMessage
    = Join User
    | Chat User String
    | Leave User
    | Update Game.Types.TableStatus
    | Roll Game.Types.Roll
    | Move Game.Types.Move
