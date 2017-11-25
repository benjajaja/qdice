module Types exposing (..)

import Navigation exposing (Location)
import Material
import Game.Types
import Editor.Types
import Backend.Types
import Board exposing (Msg)
import Tables exposing (Table)


type Msg
    = NavigateTo Route
    | OnLocationChange Location
    | Mdl (Material.Msg Msg)
    | EditorMsg Editor.Types.Msg
    | BckMsg Backend.Types.Msg
    | DrawerNavigateTo Route
    | LoggedIn (List String)
    | ChangeTable Table
    | BoardMsg Board.Msg
    | InputChat String
    | SendChat String
    | ClearChat
    | JoinGame


type StaticPage
    = Help


type Route
    = GameRoute Table
    | EditorRoute
    | StaticPageRoute StaticPage
    | NotFoundRoute


type alias Model =
    { route : Route
    , mdl :
        Material.Model
    , game : Game.Types.Model
    , editor : Editor.Types.Model
    , backend : Backend.Types.Model
    , user : User
    , tableList : List Table
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
