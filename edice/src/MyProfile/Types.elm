module MyProfile.Types exposing (DeleteAccountState(..), MyProfileModel, MyProfileMsg(..), MyProfileUpdate)

import Cropper
import File exposing (File)
import Http exposing (Error)


type MyProfileMsg
    = ChangeName String
    | ChangeEmail String
    | ChangePassword String
    | ChangePasswordCheck String
    | Save
    | DeleteAccount DeleteAccountState
    | AvatarRequested
    | AvatarSelected File
    | AvatarLoaded String
    | AvatarReset
    | ToCropper Cropper.Msg
    | Zoom String


type alias MyProfileModel =
    { name : Maybe String
    , email : Maybe String
    , password : Maybe String
    , passwordCheck : Maybe String
    , addingPassword : Bool
    , picture : Maybe String
    , cropper : Cropper.Model
    , deleteAccount : DeleteAccountState
    , saving : Bool
    }


type DeleteAccountState
    = None
    | Confirm
    | Process
    | Deleted (Result Error String)


type alias MyProfileUpdate =
    { name : Maybe String
    , email : Maybe String
    , picture : Maybe Cropper.CropData
    , password : Maybe String
    , passwordCheck : Maybe String
    }
