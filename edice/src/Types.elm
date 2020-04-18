module Types exposing (..)

import Animation
import Backend.Types
import Board
import Browser
import Browser.Navigation exposing (Key)
import Dict exposing (Dict)
import Game.Types exposing (Award, PlayerAction, TableInfo)
import Games.Types exposing (Game, GameRef)
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
    | Resized Int Int
    | UserZone Time.Zone
    | Animate Animation.Msg
    | MyProfileMsg MyProfile.Types.MyProfileMsg
    | ErrorToast String String
    | MessageToast String (Maybe Int)
    | RequestFullscreen
    | RequestNotifications
    | RenounceNotifications
    | SetSessionPreference SessionPreference
    | NotificationsChange ( String, Maybe PushSubscription, Maybe String ) -- 3rd item is JWT, because this might come right after logout
    | PushGetKey
    | PushKey (Result Error String)
    | PushRegister PushSubscription
    | PushRegisterEvent ( PushEvent, Bool )
    | LeaderboardMsg LeaderboardMsg
    | GamesMsg GamesMsg
    | RuntimeError String String
      -- oauth
    | Nop
    | GetGlobalSettings (Result Error GlobalQdice)
    | Authorize AuthState
    | GetToken (Maybe Table) (Result Error String)
    | GetUpdateProfile (Result String String)
    | GetProfile (Result Error ( LoggedUser, String, Preferences ))
    | GetOtherProfile (Result Error OtherProfile)
    | Logout
    | ShowLogin LoginDialogStatus
    | Register String (Maybe Table)
    | SetLoginName String
    | SetLoginPassword LoginPasswordStep
    | SetPassword ( String, String ) (Maybe String) -- (email, pass) check
    | UpdateUser LoggedUser String Preferences
    | GetChangelog (Result Error String)
    | GetComments CommentKind (Result String String)
    | InputComment CommentKind String
    | PostComment CommentKind String
    | GetPostComment CommentKind (Result String ())
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


type LoginPasswordStep
    = StepEmail String
    | StepPassword String
    | StepNext Int (Maybe Table)


type StaticPage
    = Help
    | About


type Route
    = HomeRoute
    | GameRoute Table
    | StaticPageRoute StaticPage
    | ChangelogRoute
    | NotFoundRoute
    | MyProfileRoute
    | TokenRoute String
    | ProfileRoute UserId String
    | LeaderBoardRoute
    | GamesRoute GamesSubRoute


type GamesSubRoute
    = AllGames
    | GamesOfTable Table
    | GameId Table Int


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
    , zone : Time.Zone
    , isTelegram : Bool
    , zip : Bool
    , screenshot : Bool
    , loginName : String
    , loginPassword :
        { step : Int
        , email : String
        , password : String
        , animations : ( Animation.State, Animation.State )
        }
    , showLoginDialog : LoginDialogStatus
    , settings : GlobalSettings
    , leaderBoard : LeaderBoardModel
    , otherProfile : Maybe OtherProfile
    , preferences : Preferences
    , sessionPreferences : SessionPreferences
    , games :
        { tables : Dict String (List Game)
        , all : List Game
        , fetching : Maybe GamesSubRoute
        }
    , changelog : Changelog
    , fullscreen : Bool
    , comments : CommentsModel
    }


type alias Flags =
    { version : String
    , token : Maybe String
    , isTelegram : Bool
    , screenshot : Bool
    , notificationsEnabled : Bool
    , muted : Bool
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
    = None
    | Password
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


type alias GlobalQdice =
    { settings : GlobalSettings
    , tables : List TableInfo
    , leaderBoard : ( String, List Profile )
    , version : String
    }


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


type alias OtherProfile =
    ( Profile, ProfileStats )


type alias ProfileStats =
    { games : List GameRef
    , gamesWon : Int
    , gamesPlayed : Int
    }


type alias LeaderBoardModel =
    { loading : Bool
    , month : String
    , top : List Profile
    , board : List Profile
    , page : Int
    }


type alias LeaderBoardResponse =
    { month : String
    , board : List Profile
    , page : Int
    }


type alias Preferences =
    { pushEvents : List PushEvent
    }


type alias SessionPreferences =
    { notificationsEnabled : Bool
    , muted : Bool
    }


type SessionPreference
    = Muted Bool


type alias PushSubscription =
    String


type PushEvent
    = GameStart
    | PlayerJoin


type LeaderboardMsg
    = GetLeaderboard (Result Error LeaderBoardResponse)
    | GotoPage Int


type GamesMsg
    = GetGames GamesSubRoute (Result Error (List Game))


type Changelog
    = ChangelogFetching
    | ChangelogFetched String
    | ChangelogError String


type CommentKind
    = UserWall String String


commentKindKey : CommentKind -> String
commentKindKey kind =
    case kind of
        UserWall id _ ->
            "user/" ++ id


type alias Comment =
    { kind : CommentKind
    , author : Profile
    , timestamp : Time.Posix
    , text : String
    }


type CommentList
    = CommentListFetching
    | CommentListError String
    | CommentListFetched (List Comment)


type alias CommentModel =
    { list : CommentList
    , postState :
        { value : String
        , status : CommentPostStatus
        }
    }


type CommentPostStatus
    = CommentPostIdle
    | CommentPosting
    | CommentPostError String
    | CommentPostSuccess


type alias CommentsModel =
    Dict String CommentModel
