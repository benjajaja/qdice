module Types exposing (..)

import Hop.Types exposing (Address, Query)
import Material
import Game.Types
import Editor.Types
import Backend.Types
import Tables exposing (Table)


type Msg
    = NavigateTo String
    | SetQuery Query
    | Mdl (Material.Msg Msg)
    | GameMsg Game.Types.Msg
    | EditorMsg Editor.Types.Msg
    | BckMsg Backend.Types.Msg
    | DrawerNavigateTo String


type GameRoute
    = GameRoute
    | GameTableRoute Table


type Route
    = GameRoutes GameRoute
    | EditorRoute
    | NotFoundRoute


type alias Model =
    { address : Address
    , route : Route
    , mdl :
        Material.Model
    , game : Game.Types.Model
    , editor : Editor.Types.Model
    , backend : Backend.Types.Model
    , user : User
    }


type User
    = Anonymous
    | Logged LoggedUser


type alias LoggedUser =
    { name : Username
    }


type alias Username =
    String
