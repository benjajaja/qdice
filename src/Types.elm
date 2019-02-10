module Types exposing (GlobalSettings, LoggedUser, LoginDialogStatus(..), Model, Msg(..), MyOAuthModel, Profile, Route(..), StaticPage(..), User(..), UserId, Username, getUsername)

import Animation
import Backend.Types
import Board exposing (Msg)
import Game.Types exposing (GameStatus, PlayerAction, TableInfo, TableStatus)
import Http
import Url exposing (Url)
import MyProfile.Types
import OAuth
import Tables exposing (Table)
import Time
import Browser
import Browser.Navigation exposing (Key)


type Msg
    = NavigateTo Route
    | OnLocationChange Url
    | OnUrlRequest Browser.UrlRequest
    | Tick Time.Posix
    | Animate Animation.Msg
    | MyProfileMsg MyProfile.Types.Msg
    | ErrorToast String String
      -- oauth
    | Nop
    | GetGlobalSettings (Result Http.Error ( GlobalSettings, List TableInfo ))
    | Authorize AuthState
    | Authenticate String AuthState
    | GetToken AuthState (Result Http.Error String)
    | GetProfile (Result Http.Error ( LoggedUser, String ))
    | GetLeaderBoard (Result Http.Error ( String, List Profile ))
    | Logout
    | ShowLogin LoginDialogStatus
    | Login String
    | SetLoginName String
    | UpdateUser LoggedUser String
      -- game
    | BoardMsg Board.Msg
    | InputChat String
    | SendChat String
    | GameCmd PlayerAction
    | EnterGame Table
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
    | SetLastHeartbeat Time.Posix


type alias AuthState =
    Maybe Table


type StaticPage
    = Help
    | About


type Route
    = HomeRoute
    | GameRoute Table
    | StaticPageRoute StaticPage
    | NotFoundRoute
    | MyProfileRoute
    | TokenRoute String
    | ProfileRoute String
    | LeaderBoardRoute


type alias Model =
    { route : Route
    , key : Key
    , oauth : MyOAuthModel
    , game : Game.Types.Model
    , myProfile : MyProfile.Types.Model
    , backend : Backend.Types.Model
    , user : User
    , tableList : List TableInfo
    , time : Time.Posix
    , isTelegram : Bool
    , loginName : String
    , showLoginDialog : LoginDialogStatus
    , settings : GlobalSettings
    , staticPage :
        { help :
            { tab : Int }
        , leaderBoard :
            { month : String
            , top : List Profile
            }
        }
    }


type User
    = Anonymous
    | Logged LoggedUser


type alias LoggedUser =
    { id : UserId
    , name : Username
    , email : Maybe String
    , picture : String
    , points : Int
    , level : Int
    }


type alias MyOAuthModel =
    { clientId : String
    , redirectUri : Url
    , error : Maybe String
    , token : Maybe OAuth.Token
    , state : String
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
    { gameCountdownSeconds : Int
    , maxNameLength : Int
    , turnSeconds : Int
    }


type LoginDialogStatus
    = LoginShow
    | LoginShowJoin
    | LoginHide


type alias Profile =
    { id : UserId
    , name : Username
    , rank : Int
    , picture : String
    , points : Int
    , level : Int
    }
