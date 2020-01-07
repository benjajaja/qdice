module LeaderBoard.State exposing (fetchLeaderboard, setLeaderBoard, update)

import Backend.HttpCommands exposing (leaderBoard)
import Helpers exposing (httpErrorToString)
import Http exposing (Error)
import Snackbar exposing (toastError)
import Types exposing (LeaderBoardResponse, LeaderboardMsg(..), Model, Msg, Profile)


update : Model -> LeaderboardMsg -> ( Model, Cmd Msg )
update model msg =
    case msg of
        GetLeaderboard res ->
            setLeaderBoard model res

        GotoPage num ->
            fetchLeaderboard model num


fetchLeaderboard : Model -> Int -> ( Model, Cmd Msg )
fetchLeaderboard model page =
    let
        mLeaderboard =
            model.leaderBoard
    in
    ( { model | leaderBoard = { mLeaderboard | loading = True, page = page } }
    , leaderBoard model.backend page
    )


setLeaderBoard : Model -> Result Error LeaderBoardResponse -> ( Model, Cmd Msg )
setLeaderBoard model res =
    case res of
        Err err ->
            ( model, toastError "Could not load leaderboard" <| httpErrorToString err )

        Ok data ->
            let
                leaderBoard =
                    model.leaderBoard
            in
            ( { model
                | leaderBoard =
                    { leaderBoard
                        | loading = False
                        , month = data.month
                        , top = leaderBoard.top
                        , board = data.board
                        , page = data.page
                    }
              }
            , Cmd.none
            )
