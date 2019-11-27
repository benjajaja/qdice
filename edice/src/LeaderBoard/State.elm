module LeaderBoard.State exposing (setLeaderBoard)

import Http
import Snackbar exposing (toastError)
import Types exposing (Model, Msg, Profile)
import Helpers exposing (httpErrorToString)


setLeaderBoard : Model -> Result Http.Error ( String, List Profile ) -> ( Model, Cmd Msg )
setLeaderBoard model res =
    case res of
        Err err ->
            ( model, toastError "Could not load leaderboard" <| httpErrorToString err )

        Ok ( month, top ) ->
            let
                staticPage =
                    model.staticPage

                leaderBoard =
                    staticPage.leaderBoard
            in
                ( { model
                    | staticPage =
                        { staticPage
                            | leaderBoard =
                                { leaderBoard
                                    | month = month
                                    , top = top
                                }
                        }
                  }
                , Cmd.none
                )
