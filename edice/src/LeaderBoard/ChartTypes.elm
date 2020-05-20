module LeaderBoard.ChartTypes exposing (..)


type alias Datum =
    { time : Int
    , score : Int
    }


type alias PlayerRef =
    { id : String
    , name : String
    , picture : String
    }
