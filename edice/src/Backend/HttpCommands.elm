module Backend.HttpCommands exposing (authenticate, deleteAccount, leaderBoard, loadGlobalSettings, loadMe, login, toastHttpError, updateAccount)

import Backend.Decoding exposing (..)
import Backend.Encoding exposing (..)
import Backend.MessageCodification exposing (..)
import Backend.Types exposing (..)
import Game.Types exposing (Player, PlayerAction(..))
import Helpers exposing (httpErrorToString)
import Http exposing (Error, emptyBody, expectJson, expectString, header, jsonBody, stringBody)
import Land exposing (Color(..))
import Snackbar exposing (toastError)
import Tables exposing (Table)
import Types exposing (AuthNetwork(..), AuthState, LoggedUser, LoginDialogStatus(..), Msg(..), User(..))


toastHttpError : Error -> Cmd Msg
toastHttpError err =
    toastError (httpErrorToString err) (httpErrorToString err)


loadGlobalSettings : Model -> Cmd Msg
loadGlobalSettings model =
    Http.get
        { url = model.baseUrl ++ "/global"
        , expect = expectJson GetGlobalSettings globalDecoder
        }


authenticate : Model -> String -> AuthState -> Cmd Msg
authenticate model code state =
    case state.addTo of
        Nothing ->
            Http.post
                { url = model.baseUrl ++ "/login/" ++ encodeAuthNetwork state.network
                , body = stringBody "text/plain" code
                , expect = expectString (GetToken <| Just state)
                }

        Just userId ->
            Http.request
                { method = "POST"
                , url = model.baseUrl ++ "/add-login/" ++ encodeAuthNetwork state.network
                , headers =
                    case model.jwt of
                        Just jwt ->
                            [ header "authorization" ("Bearer " ++ jwt) ]

                        Nothing ->
                            []
                , body = stringBody "text/plain" code
                , expect = expectJson (GetToken <| Just state) tokenDecoder
                , timeout = Nothing
                , tracker = Nothing
                }


loadMe : Model -> Cmd Msg
loadMe model =
    Http.request
        { method = "GET"
        , url = model.baseUrl ++ "/me"
        , body = emptyBody
        , headers =
            case model.jwt of
                Just jwt ->
                    [ header "authorization" ("Bearer " ++ jwt) ]

                Nothing ->
                    []
        , expect =
            expectJson GetProfile meDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


leaderBoard : Model -> Cmd Msg
leaderBoard model =
    Http.get
        { url = model.baseUrl ++ "/leaderboard"
        , expect = expectJson GetLeaderBoard leaderBoardDecoder
        }


login : Types.Model -> String -> ( Types.Model, Cmd Msg )
login model name =
    let
        profile =
            { name = name
            , id = "💩"
            , email = Nothing
            , picture = ""
            , points = 0
            , rank = 0
            , level = 0
            , claimed = False
            , networks = [ Password ]
            }

        state =
            { network = Password, table = model.game.table, addTo = Nothing }
    in
    ( { model | showLoginDialog = LoginHide }
    , Http.post
        { url = model.backend.baseUrl ++ "/register"
        , body =
            jsonBody <| profileEncoder profile
        , expect =
            expectJson (GetToken <| Just state) tokenDecoder
        }
    )


updateAccount : Model -> LoggedUser -> Cmd Msg
updateAccount model profile =
    Http.request
        { method = "PUT"
        , headers =
            case model.jwt of
                Just jwt ->
                    [ header "authorization" ("Bearer " ++ jwt) ]

                Nothing ->
                    []
        , url = model.baseUrl ++ "/profile"
        , body =
            jsonBody <| profileEncoder profile
        , expect =
            expectJson (GetToken Nothing) tokenDecoder
        , timeout = Nothing
        , tracker = Nothing
        }


deleteAccount : (Result Error String -> Msg) -> Model -> User -> Cmd Msg
deleteAccount msg model user =
    case user of
        Logged logged ->
            Http.request
                { method = "DELETE"
                , headers =
                    case model.jwt of
                        Just jwt ->
                            [ header "authorization" ("Bearer " ++ jwt) ]

                        Nothing ->
                            []
                , url = model.baseUrl ++ "/me"
                , body =
                    emptyBody
                , expect =
                    expectString msg
                , timeout = Nothing
                , tracker = Nothing
                }

        _ ->
            toastError "Error: not logged in" ""
