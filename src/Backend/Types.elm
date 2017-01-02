module Backend.Types exposing (..)

import Tables exposing (Table(..))


type Msg
    = Connect ClientId
    | Subscribed Topic
    | ClientMsg ClientMessage
    | AllClientsMsg AllClientsMessage
    | TableMsg Table TableMessage
    | UnknownTopicMessage String String String


type alias Model =
    { clientId : ClientId
    , subscribed : List Topic
    }


type alias ClientId =
    String


type Topic
    = Client
    | AllClients
    | Tables Table


type ClientMessage
    = None


type AllClientsMessage
    = PresentYourself


type TableMessage
    = Join User


type alias User =
    String
