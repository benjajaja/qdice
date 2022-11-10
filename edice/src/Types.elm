module Types exposing (AuthNetwork(..), AuthState, Comment, CommentAuthor, CommentKind(..), CommentList(..), CommentModel, CommentPostStatus(..), CommentsModel, DialogStatus(..), DialogType(..), Flags, GamesMsg(..), GamesSubRoute(..), GlobalQdice, GlobalSettings, LeaderBoardModel, LeaderBoardResponse, LeaderboardMsg(..), LoggedUser, LoginDialogStatus(..), LoginPasswordStep(..), Model, Msg(..), MyOAuthModel, OtherProfile, Preferences, Profile, ProfileStats, ProfileStatsStatistics, PushEvent(..), PushSubscription, Replies(..), Route(..), SessionPreference(..), SessionPreferences, StaticPage(..), TableStatPlayer, TableStats, User(..), UserId, UserPreferences, Username, commentKindKey, getUsername)

import Animation
import Array exposing (Array)
import Backend.Types
import Board.Types
import Browser
import Browser.Navigation exposing (Key)
import Dict exposing (Dict)
import Game.Types exposing (Award, PlayerAction, TableInfo)
import Games.Replayer.Types exposing (ReplayerCmd, ReplayerModel)
import Games.Types exposing (Game, GameRef, GamesModel)
import Html
import Http exposing (Error)
import LeaderBoard.ChartTypes exposing (Datum, PlayerRef)
import MyProfile.Types
import OAuth
import Placeholder exposing (Placeheld)
import Tables exposing (Table)
import Time
import Url exposing (Url)


type Msg
    = NavigateTo Route
    | OnLocationChange Url
    | OnUrlRequest Browser.UrlRequest
    | Frame Time.Posix
    | Resized Int Int
    | UserZone ( Time.Zone, Time.Posix )
    | Animate Animation.Msg
    | MyProfileMsg MyProfile.Types.MyProfileMsg
    | ErrorToast String String
    | MessageToast String (Maybe Int)
    | RequestFullscreen
    | RequestNotifications
    | RenounceNotifications
    | SetSessionPreference SessionPreference
    | NotificationsChange ( String, Maybe PushSubscription, Maybe String ) -- 3rd item is JWT, because this might come right after logout
    | NotificationClick String
    | PushNotification String
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
    | ShowDialog DialogType
    | HideDialog
    | Register String (Maybe Table)
    | SetLoginName String
    | SetLoginPassword LoginPasswordStep
    | SetPassword ( String, String ) (Maybe String) -- (email, pass) check
    | UpdateUser LoggedUser String Preferences
    | GetComments CommentKind (Result String (List Comment))
    | InputComment CommentKind String
    | PostComment CommentKind (Maybe CommentKind) String
    | GetPostComment CommentKind (Maybe CommentKind) (Result String Comment)
    | ReplyComment CommentKind (Maybe ( Int, String ))
    | GetTableStats (Result String TableStats)
      -- game
    | BoardMsg Board.Types.Msg
    | InputChat String
    | SendChat String
    | GameCmd PlayerAction
    | GameMsg Game.Types.Msg
    | ExpandChats
    | FindGame (Maybe Table)
      -- replayer
    | ReplayerCmd ReplayerCmd
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
    | UnknownTopicMessage String String String Backend.Types.ConnectionStatus
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
    | NotFoundRoute
    | MyProfileRoute
    | TokenRoute String
    | ProfileRoute UserId String
    | LeaderBoardRoute
    | GamesRoute GamesSubRoute
    | CommentsRoute


type GamesSubRoute
    = AllGames
    | GamesOfTable Table
    | GameId Table Int


type alias Model =
    { route : Route
    , key : Key
    , oauth : MyOAuthModel
    , game : Game.Types.Model
    , tableStats : Placeheld TableStats
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
    , dialog : DialogStatus
    , settings : GlobalSettings
    , leaderBoard : LeaderBoardModel
    , otherProfile : Placeheld OtherProfile
    , preferences : Preferences
    , sessionPreferences : SessionPreferences
    , games : Placeheld GamesModel
    , fullscreen : Maybe Int
    , comments : CommentsModel
    , replayer : Maybe ReplayerModel
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
    = Password
    | Google
    | Github
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


type DialogStatus
    = Show DialogType
    | Hide


type DialogType
    = Login
    | LoginJoin
    | Confirm (Model -> ( String, List (Html.Html Msg) )) Msg


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
    , registered : Bool
    }


type alias OtherProfile =
    ( Profile, ProfileStats )


type alias ProfileStats =
    { games : List GameRef
    , gamesWon : Int
    , gamesPlayed : Int
    , stats : ProfileStatsStatistics
    }


type alias ProfileStatsStatistics =
    { rolls : Array Int
    , attacks : ( Int, Int )
    , kills : Int
    , eliminations : Array Int
    , luck : ( Int, Int )
    }


type alias LeaderBoardModel =
    { loading : Bool
    , month : String
    , top : List Profile
    , board : List Profile
    , page : Int
    }


type alias TableStats =
    { table : Table
    , period : String
    , top : List TableStatPlayer
    , daily : List ( PlayerRef, List Datum )
    }


type alias TableStatPlayer =
    { id : String, name : String, picture : String, score : Int }


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
    | Turn


type LeaderboardMsg
    = GetLeaderboard (Result Error LeaderBoardResponse)
    | GotoPage Int


type GamesMsg
    = GetGames GamesSubRoute (Result Error (List Game))


type CommentKind
    = UserWall String String
    | GameComments Int String
    | TableComments String
    | ReplyComments Int String
    | StaticPageComments StaticPage
    | AllComments


commentKindKey : CommentKind -> String
commentKindKey kind =
    case kind of
        UserWall id _ ->
            "user/" ++ id

        GameComments id _ ->
            "games/" ++ String.fromInt id

        TableComments table ->
            "tables/" ++ table

        ReplyComments id _ ->
            "comments/" ++ String.fromInt id

        StaticPageComments page ->
            "page/"
                ++ (case page of
                        Help ->
                            "help"

                        About ->
                            "about"
                   )

        AllComments ->
            "all"


type alias Comment =
    { id : Int
    , kind : CommentKind
    , author : CommentAuthor
    , timestamp : Int
    , text : String
    , replies : Replies
    }


type Replies
    = Replies (List Comment)


type alias CommentAuthor =
    { id : Int
    , name : String
    , picture : String
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
        , kind : Maybe CommentKind
        }
    }


type CommentPostStatus
    = CommentPostIdle
    | CommentPosting
    | CommentPostError String
    | CommentPostSuccess


type alias CommentsModel =
    Dict String CommentModel
