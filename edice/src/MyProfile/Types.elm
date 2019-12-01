module MyProfile.Types exposing (DeleteAccountState(..), MyProfileModel, MyProfileMsg(..))

import Http exposing (Error)


type MyProfileMsg
    = ChangeName String
    | ChangeEmail String
    | Save
    | DeleteAccount DeleteAccountState


type alias MyProfileModel =
    { name : Maybe String
    , email : Maybe String
    , deleteAccount : DeleteAccountState
    }


type DeleteAccountState
    = None
    | Confirm
    | Process
    | Deleted (Result Error String)
