module Types exposing (..)

import Navigation exposing (Location)
import Http
import Time
import Material
import Snackbar.Types
import OAuth
import Animation
import Game.Types exposing (TableStatus, PlayerAction, GameStatus, TableInfo)
import Editor.Types
import MyProfile.Types
import Backend.Types
import Board exposing (Msg)
import Tables exposing (Table(..))


type Msg
    = NavigateTo Route
    | OnLocationChange Location
    | Tick Time.Time
    | Mdl (Material.Msg Msg)
    | DrawerNavigateTo Route
    | Snackbar Snackbar.Types.Msg
    | Animate Animation.Msg
    | EditorMsg Editor.Types.Msg
    | MyProfileMsg MyProfile.Types.Msg
    | ErrorToast String
      -- oauth
    | Nop
    | GetGlobalSettings (Result Http.Error ( GlobalSettings, List TableInfo ))
    | Authorize Bool
    | Authenticate String Bool
    | GetToken Bool (Result Http.Error String)
    | GetProfile (Result Http.Error LoggedUser)
    | Logout
    | Login String
    | SetLoginName String
      -- game
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
    | About


type Route
    = GameRoute Table
    | EditorRoute
    | StaticPageRoute StaticPage
    | NotFoundRoute
    | MyProfileRoute
    | TokenRoute String


type alias Model =
    { route : Route
    , mdl :
        Material.Model
    , oauth : MyOAuthModel
    , game : Game.Types.Model
    , editor : Editor.Types.Model
    , myProfile : MyProfile.Types.Model
    , backend : Backend.Types.Model
    , user : User
    , tableList : List TableInfo
    , time : Time.Time
    , snackbar : Snackbar.Types.Model
    , isTelegram : Bool
    , loginName : String
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


type alias GlobalSettings =
    {}
