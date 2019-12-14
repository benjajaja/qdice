module LeaderBoard.State exposing (setLeaderBoard)

import Helpers exposing (httpErrorToString)
import Http exposing (Error)
import Snackbar exposing (toastError)
import Types exposing (Model, Msg, Profile)


setLeaderBoard : Model -> Result Error ( String, List Profile ) -> ( Model, Cmd Msg )
setLeaderBoard model res =
    case res of
        Err err ->
            ( model, toastError "Could not load leaderboard" <| httpErrorToString err )

        Ok ( month, top ) ->
            let
                leaderBoard =
                    model.leaderBoard
            in
            ( { model
                | leaderBoard =
                    { leaderBoard
                        | month = month
                        , top = top
                    }
              }
            , Cmd.none
            )
