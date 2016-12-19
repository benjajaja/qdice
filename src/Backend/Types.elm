module Backend.Types exposing (..)

import Tables exposing (Table(..))


type Msg
    = Connect ClientId
    | Subscribed Topic
    | Message Topic Command


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


type Command
    = PresentYourself
    | Join
