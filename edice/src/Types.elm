module Types exposing (AuthNetwork(..), AuthState, Flags, GlobalSettings, LoggedUser, LoginDialogStatus(..), Model, Msg(..), MyOAuthModel, Preferences, Profile, PushEvent(..), PushSubscription, Route(..), SessionPreferences, StaticPage(..), User(..), UserId, Username, getUsername)

import Animation
import Backend.Types
import Board
import Browser
import Browser.Navigation exposing (Key)
import Game.Types exposing (Award, PlayerAction, TableInfo)
import Http exposing (Error)
import MyProfile.Types
import OAuth
import Tables exposing (Table)
import Time
import Url exposing (Url)


type Msg
    = NavigateTo Route
    | OnLocationChange Url
    | OnUrlRequest Browser.UrlRequest
    | Tick Time.Posix
    | Animate Animation.Msg
    | MyProfileMsg MyProfile.Types.MyProfileMsg
    | ErrorToast String String
    | MessageToast String (Maybe Int)
    | RequestFullscreen
    | RequestNotifications
    | RenounceNotifications
    | NotificationsChange ( String, Maybe PushSubscription, Maybe String ) -- 3rd item is JWT, because this might come right after logout
    | PushGetKey
    | PushKey (Result Error String)
    | PushRegister PushSubscription
    | PushRegisterEvent ( PushEvent, Bool )
      -- oauth
    | Nop
    | GetGlobalSettings (Result Error ( GlobalSettings, List TableInfo, ( String, List Profile ) ))
    | Authorize AuthState
    | Authenticate String AuthState
    | GetToken (Maybe AuthState) (Result Error String)
    | GetProfile (Result Error ( LoggedUser, String, Preferences ))
    | GetOtherProfile (Result Error Profile)
    | GetLeaderBoard (Result Error ( String, List Profile ))
    | Logout
    | ShowLogin LoginDialogStatus
    | Login String
    | SetLoginName String
    | UpdateUser LoggedUser String Preferences
      -- game
    | BoardMsg Board.Msg
    | InputChat String
    | SendChat String
    | GameCmd PlayerAction
    | GameMsg Game.Types.Msg
    | EnterGame Table
      -- backend
    | Connected Backend.Types.ClientId
    | StatusConnect String
    | StatusReconnect Int
    | StatusOffline String
    | StatusError String
    | Subscribed Backend.Types.Topic
    | ClientMsg Backend.Types.ClientMessage
    | AllClientsMsg Backend.Types.AllClientsMessage
    | TableMsg Table Backend.Types.TableMessage
    | UnknownTopicMessage String String String String
    | SetLastHeartbeat Time.Posix


type alias AuthState =
    { network : AuthNetwork
    , table : Maybe Table
    , addTo : Maybe UserId
    }


type StaticPage
    = Help
    | About
    | Changelog


type Route
    = HomeRoute
    | GameRoute Table
    | StaticPageRoute StaticPage
    | NotFoundRoute
    | MyProfileRoute
    | TokenRoute String
    | ProfileRoute UserId String
    | LeaderBoardRoute


type alias Model =
    { route : Route
    , key : Key
    , oauth : MyOAuthModel
    , game : Game.Types.Model
    , myProfile : MyProfile.Types.MyProfileModel
    , backend : Backend.Types.Model
    , user : User
    , tableList : List TableInfo
    , time : Time.Posix
    , isTelegram : Bool
    , zip : Bool
    , screenshot : Bool
    , loginName : String
    , showLoginDialog : LoginDialogStatus
    , settings : GlobalSettings
    , leaderBoard : LeaderBoardModel
    , otherProfile : Maybe Profile
    , preferences : Preferences
    , sessionPreferences : SessionPreferences
    }


type alias Flags =
    { version : String
    , token : Maybe String
    , isTelegram : Bool
    , screenshot : Bool
    , notificationsEnabled : Bool
    , zip : Bool
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
    , rank : Int
    , level : Int
    , levelPoints : Int
    , claimed : Bool
    , networks : List AuthNetwork
    , voted : List String
    , awards : List Award
    }


type alias UserPreferences =
    {}


type AuthNetwork
    = Password
    | Google
    | Reddit
    | Telegram


type alias MyOAuthModel =
    { redirectUri : Url
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
    , levelPoints : Int
    , awards : List Award
    }


type alias LeaderBoardModel =
    { month : String
    , top : List Profile
    }


type alias Preferences =
    { pushEvents : List PushEvent
    }


type alias SessionPreferences =
    { notificationsEnabled : Bool
    }


type alias PushSubscription =
    String


type PushEvent
    = GameStart
    | PlayerJoin
