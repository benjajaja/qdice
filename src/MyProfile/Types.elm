module MyProfile.Types exposing (..)

import Material


type Msg
    = Mdl (Material.Msg Msg)
    | ChangeName String
    | Save


type alias Model =
    { name : Maybe String
    }
