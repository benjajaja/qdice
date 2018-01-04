module Backend.HttpCommands exposing (..)

import Http
import Land exposing (Color(..))
import Tables exposing (Table(..), decodeTable)
import Game.Types exposing (Player, PlayerAction(..))
import Backend.Types exposing (..)
import Types exposing (Msg(..))
import Backend.Decoding exposing (..)
import Backend.Encoding exposing (..)
import Backend.MessageCodification exposing (..)
import Snackbar exposing (toastCmd)


findBestTable : Model -> Cmd Msg
findBestTable model =
    Http.send FindBestTable <|
        Http.request
            { method = "GET"
            , headers = []
            , url = (model.baseUrl ++ "/findtable")
            , body = Http.emptyBody
            , expect =
                Http.expectJson <| tableNameDecoder
            , timeout = Just model.findTableTimeout
            , withCredentials = False
            }


loadGlobalSettings : Model -> Cmd Msg
loadGlobalSettings model =
    Http.send (GetGlobalSettings) <|
        Http.get (model.baseUrl ++ "/global") <|
            globalDecoder


authenticate : Model -> String -> Bool -> Cmd Msg
authenticate model code doJoin =
    let
        request =
            Http.post (model.baseUrl ++ "/login")
                (code |> Http.stringBody "text/plain")
            <|
                tokenDecoder
    in
        Http.send (GetToken doJoin) request


loadMe : Model -> Cmd Msg
loadMe model =
    Http.send GetProfile <|
        Http.request
            { method = "GET"
            , headers =
                case model.jwt of
                    Just jwt ->
                        [ Http.header "authorization" ("Bearer " ++ jwt) ]

                    Nothing ->
                        []
            , url = (model.baseUrl ++ "/me")
            , body = Http.emptyBody
            , expect =
                Http.expectJson <| meDecoder
            , timeout = Nothing
            , withCredentials = False
            }


leaderBoard : Model -> Cmd Msg
leaderBoard model =
    Http.send (GetLeaderBoard) <|
        Http.get (model.baseUrl ++ "/leaderboard") <|
            leaderBoardDecoder
