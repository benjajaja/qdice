module MyProfile.Types exposing (MyProfileModel, MyProfileMsg(..))


type MyProfileMsg
    = ChangeName String
    | Save


type alias MyProfileModel =
    { name : Maybe String
    }
