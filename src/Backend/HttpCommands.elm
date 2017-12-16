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


loadGlobalSettings : Model -> Cmd Msg
loadGlobalSettings model =
    Http.send (GetGlobalSettings) <|
        Http.get (model.baseUrl ++ "/global") <|
            globalDecoder


authenticate : Model -> String -> Cmd Msg
authenticate model code =
    let
        request =
            Http.post (model.baseUrl ++ "/login")
                (code |> Http.stringBody "text/plain")
            <|
                tokenDecoder
    in
        Http.send (GetToken) request


loadMe : Model -> Cmd Msg
loadMe model =
    Http.send GetProfile <|
        Http.request
            { method = "GET"
            , headers = [ Http.header "authorization" ("Bearer " ++ model.jwt) ]
            , url = (model.baseUrl ++ "/me")
            , body = Http.emptyBody
            , expect =
                Http.expectJson <| profileDecoder
            , timeout = Nothing
            , withCredentials = False
            }


gameCommand : Model -> Table -> PlayerAction -> Cmd Msg
gameCommand model table playerAction =
    Http.send (GameCommandResponse table playerAction) <|
        Http.request
            { method = "POST"
            , headers = [ Http.header "authorization" ("Bearer " ++ model.jwt) ]
            , url =
                (model.baseUrl
                    ++ "/tables/"
                    ++ (toString table)
                    ++ "/"
                    ++ (actionToString playerAction)
                )
            , body = Http.emptyBody
            , expect = Http.expectStringResponse (\_ -> Ok ())
            , timeout = Nothing
            , withCredentials = False
            }


attack : Model -> Table -> Land.Emoji -> Land.Emoji -> Cmd Msg
attack model table from to =
    Http.send (GameCommandResponse table <| Attack from to) <|
        Http.request
            { method = "POST"
            , headers = [ Http.header "authorization" ("Bearer " ++ model.jwt) ]
            , url =
                (model.baseUrl
                    ++ "/tables/"
                    ++ (toString table)
                    ++ "/Attack"
                )
            , body = Http.jsonBody <| attackEncoder from to
            , expect = Http.expectStringResponse (\_ -> Ok ())
            , timeout = Nothing
            , withCredentials = False
            }


actionToString : PlayerAction -> String
actionToString action =
    case action of
        Attack a b ->
            "Attack"

        _ ->
            toString action
