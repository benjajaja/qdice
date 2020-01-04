module MyProfile.Types exposing (DeleteAccountState(..), MyProfileModel, MyProfileMsg(..), MyProfileUpdate)

import File exposing (File)
import Http exposing (Error)


type MyProfileMsg
    = ChangeName String
    | ChangeEmail String
    | Save
    | DeleteAccount DeleteAccountState
    | AvatarRequested
    | AvatarSelected File
    | AvatarLoaded String


type alias MyProfileModel =
    { name : Maybe String
    , email : Maybe String
    , picture : Maybe String
    , deleteAccount : DeleteAccountState
    }


type DeleteAccountState
    = None
    | Confirm
    | Process
    | Deleted (Result Error String)


type alias MyProfileUpdate =
    { name : Maybe String
    , email : Maybe String
    , picture : Maybe String
    }
