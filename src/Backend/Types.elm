module Backend.Types exposing (..)

import Tables exposing (Table(..))


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


type alias Model =
    { clientId : ClientId
    , subscribed : List Topic
    , status : ConnectionStatus
    }


type alias ClientId =
    String


type Topic
    = Client
    | AllClients
    | Tables Table


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


type alias User =
    String
