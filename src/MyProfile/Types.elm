module MyProfile.Types exposing (Model, Msg(..))

import Material


type Msg
    = ChangeName String
    | Save


type alias Model =
    { name : Maybe String
    }
