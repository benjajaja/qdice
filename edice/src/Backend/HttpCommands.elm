module Backend.HttpCommands exposing (authenticate, leaderBoard, loadGlobalSettings, loadMe)

import Backend.Decoding exposing (..)
import Backend.Encoding exposing (..)
import Backend.MessageCodification exposing (..)
import Backend.Types exposing (..)
import Game.Types exposing (Player, PlayerAction(..))
import Http
import Land exposing (Color(..))
import Tables exposing (Table)
import Types exposing (AuthState, Msg(..))


loadGlobalSettings : Model -> Cmd Msg
loadGlobalSettings model =
    Http.send GetGlobalSettings <|
        Http.get (model.baseUrl ++ "/global") <|
            globalDecoder


authenticate : Model -> String -> AuthState -> Cmd Msg
authenticate model code state =
    case state.addTo of
        Nothing ->
            let
                request =
                    Http.post (model.baseUrl ++ "/login/" ++ encodeAuthNetwork state.network)
                        (code |> Http.stringBody "text/plain")
                        tokenDecoder
            in
            Http.send (GetToken <| Just state) request

        Just userId ->
            let
                request =
                    Http.request
                        { method = "POST"
                        , headers =
                            case model.jwt of
                                Just jwt ->
                                    [ Http.header "authorization" ("Bearer " ++ jwt) ]

                                Nothing ->
                                    []
                        , url = model.baseUrl ++ "/register/" ++ encodeAuthNetwork state.network
                        , body = Http.stringBody "text/plain" code
                        , expect =
                            Http.expectJson <| tokenDecoder
                        , timeout = Nothing
                        , withCredentials = False
                        }
            in
            Http.send (GetToken <| Just state) request


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
            , url = model.baseUrl ++ "/me"
            , body = Http.emptyBody
            , expect =
                Http.expectJson <| meDecoder
            , timeout = Nothing
            , withCredentials = False
            }


leaderBoard : Model -> Cmd Msg
leaderBoard model =
    Http.send GetLeaderBoard <|
        Http.get (model.baseUrl ++ "/leaderboard") <|
            leaderBoardDecoder
