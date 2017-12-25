module Backend.Types exposing (..)

import Tables exposing (Table)
import Game.Types


type alias Model =
    { baseUrl : String
    , jwt : Maybe String
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


type TableMessage
    = Join Game.Types.User
    | Chat Game.Types.User String
    | Leave Game.Types.User
    | Update Game.Types.TableStatus
    | Roll Game.Types.Roll
    | Move Game.Types.Move
    | Elimination Game.Types.Elimination
