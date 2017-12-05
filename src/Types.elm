module Types exposing (..)

import Navigation exposing (Location)
import Http
import Material
import OAuth
import Game.Types
import Game.Types exposing (TableStatus, PlayerAction)
import Editor.Types
import Backend.Types
import Board exposing (Msg)
import Tables exposing (Table(..))


type Msg
    = NavigateTo Route
    | OnLocationChange Location
    | Mdl (Material.Msg Msg)
    | DrawerNavigateTo Route
    | EditorMsg Editor.Types.Msg
      -- oauth
    | Nop
    | Authorize
    | Authenticate String
    | GetToken (Result Http.Error String)
    | GetProfile (Result Http.Error LoggedUser)
    | Logout
      -- game
    | ChangeTable Table
    | BoardMsg Board.Msg
    | InputChat String
    | SendChat String
    | ClearChat
    | GameCmd PlayerAction
      -- backend
    | LoadToken String
    | Connected Backend.Types.ClientId
    | StatusConnect String
    | StatusReconnect Int
    | StatusOffline String
    | Subscribed Backend.Types.Topic
    | ClientMsg Backend.Types.ClientMessage
    | AllClientsMsg Backend.Types.AllClientsMessage
    | TableMsg Table Backend.Types.TableMessage
    | UnknownTopicMessage String String String
    | GameCommandResponse Table PlayerAction (Result Http.Error ())


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
    , oauth : MyOAuthModel
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
    { id : UserId
    , name : Username
    , email : String
    , picture : String
    }


type alias MyOAuthModel =
    { clientId : String
    , redirectUri : String
    , error : Maybe String
    , token : Maybe OAuth.Token
    }


getUsername : Model -> String
getUsername model =
    case model.user of
        Anonymous ->
            "Anonymous"

        Logged user ->
            user.name


type alias UserId =
    String


type alias Username =
    String
