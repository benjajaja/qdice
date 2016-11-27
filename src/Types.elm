module Types exposing (..)

import Hop.Types exposing (Address, Query)
import Material
import Editor.Types


type Msg
    = NavigateTo String
    | SetQuery Query
    | Mdl (Material.Msg Msg)
    | EditorMsg Editor.Types.Msg


type Route
    = GameRoute
    | EditorRoute
    | NotFoundRoute


type alias Model =
    { address : Address
    , route : Route
    , mdl : Material.Model
    , editor : Editor.Types.Model
    }
