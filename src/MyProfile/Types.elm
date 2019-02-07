module MyProfile.Types exposing (Model, Msg(..))


type Msg
    = ChangeName String
    | Save


type alias Model =
    { name : Maybe String
    }
