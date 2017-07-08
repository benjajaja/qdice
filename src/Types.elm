module Types exposing (..)

import Navigation exposing (Location)
import Material
import Game.Types
import Editor.Types
import Backend.Types
import Tables exposing (Table)


type Msg
    = NavigateTo Route
      -- | SetQuery Query
    | OnLocationChange Location
    | Mdl (Material.Msg Msg)
    | GameMsg Game.Types.Msg
    | EditorMsg Editor.Types.Msg
    | BckMsg Backend.Types.Msg
    | DrawerNavigateTo Route
    | LoggedIn (List String)


type GameRoute
    = GameRoute
    | GameTableRoute Table


type Route
    = GameRoutes GameRoute
    | EditorRoute
    | NotFoundRoute


type alias Model =
    -- { address : Address
    { route : Route
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
    , email : String
    , picture : String
    }


getUsername : Model -> String
getUsername model =
    case model.user of
        Anonymous ->
            "Anonymous"

        Logged user ->
            user.name


type alias Username =
    String
