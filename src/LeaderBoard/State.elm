module LeaderBoard.State exposing (setLeaderBoard)

import Http
import Snackbar exposing (toast)
import Types exposing (Model, Msg, Profile)


setLeaderBoard : Model -> Result Http.Error ( String, List Profile ) -> ( Model, Cmd Msg )
setLeaderBoard model res =
    case res of
        Err err ->
            let
                _ =
                    Debug.log "board error" err
            in
            toast model "Could not load leaderboard"

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
