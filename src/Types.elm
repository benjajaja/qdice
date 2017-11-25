module Types exposing (..)

import Navigation exposing (Location)
import Http
import Material
import Game.Types
import Game.Types exposing (TableStatus)
import Editor.Types
import Backend.Types
import Board exposing (Msg)
import Tables exposing (Table(..))


type Msg
    = NavigateTo Route
    | OnLocationChange Location
    | Mdl (Material.Msg Msg)
    | EditorMsg Editor.Types.Msg
    | DrawerNavigateTo Route
    | LoggedIn (List String)
      -- game
    | ChangeTable Table
    | BoardMsg Board.Msg
    | InputChat String
    | SendChat String
    | ClearChat
    | JoinGame
      -- backend
    | Connected Backend.Types.ClientId
    | StatusConnect String
    | StatusReconnect Int
    | StatusOffline String
    | Subscribed Backend.Types.Topic
    | ClientMsg Backend.Types.ClientMessage
    | AllClientsMsg Backend.Types.AllClientsMessage
    | TableMsg Table Backend.Types.TableMessage
    | UnknownTopicMessage String String String
    | JoinTable Table
    | Joined (Result Http.Error TableStatus)


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
