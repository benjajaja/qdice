module LeaderBoard.Types exposing (LeaderBoardModel)

import Types exposing (Profile)


type alias LeaderBoardModel =
    { month : String
    , top : List Profile
    }
