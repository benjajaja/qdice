module MyProfile.Types exposing (MyProfileModel, MyProfileMsg(..))


type MyProfileMsg
    = ChangeName String
    | ChangeEmail String
    | Save


type alias MyProfileModel =
    { name : Maybe String
    , email : Maybe String
    }
