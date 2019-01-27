module Backend.Types exposing (AllClientsMessage(..), ClientId, ClientMessage(..), ConnectionStatus(..), Model, TableMessage(..), Topic(..), TopicDirection(..))

import Game.Types
import Tables exposing (Table)
import Time


type alias Model =
    { baseUrl : String
    , jwt : Maybe String
    , clientId : Maybe ClientId
    , subscribed : List Topic
    , status : ConnectionStatus
    , findTableTimeout : Float
    , lastHeartbeat : Time.Posix
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
    = Join (Maybe Game.Types.User)
    | Chat (Maybe Game.Types.User) String
    | Leave (Maybe Game.Types.User)
    | Update Game.Types.TableStatus
    | Roll Game.Types.Roll
    | Move Game.Types.Move
    | Elimination Game.Types.Elimination
    | Error String
