module Backend.Types exposing (..)

import Game.Types
import Tables exposing (Table)
import Time


type alias Model =
    { version : String
    , baseUrl : String
    , jwt : Maybe String
    , status : ConnectionStatus
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


type ConnectionStatus
    = Offline (Maybe Table)
    | Connecting (Maybe Table)
    | Reconnecting Int (Maybe Table)
    | Subscribing String SubscriptionStatus
    | Online String Table


type alias SubscriptionStatus =
    ( ( Bool, Bool ), Maybe Table )


type ClientMessage
    = None


type AllClientsMessage
    = TablesInfo (List Game.Types.TableInfo)
    | SigInt
    | Toast String
    | ServerOnline String String


type TableMessage
    = Enter (Maybe Game.Types.User)
    | Chat (Maybe Game.Types.User) String
    | Exit (Maybe Game.Types.User)
    | Join Game.Types.Player
    | Leave Game.Types.Player
    | Update Game.Types.TableStatus
    | Roll Game.Types.Roll
    | Move Game.Types.Move
    | Eliminations (List Game.Types.Elimination) (List Game.Types.Player)
    | Error String
    | Turn Game.Types.TurnInfo
    | PlayerStatus Game.Types.Player


type alias HttpStringError =
    ( Int, String )
