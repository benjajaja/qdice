module LeaderBoard.Types exposing (..)

import Types exposing (Profile)


type alias LeaderBoardModel =
    { month : String
    , top : List Profile
    }
