module Backend.HttpCommands exposing (authenticate, deleteAccount, getPushKey, leaderBoard, loadGlobalSettings, loadMe, login, registerPush, registerPushEvent, toastHttpError, updateAccount)

import Backend.Decoding exposing (..)
import Backend.Encoding exposing (..)
import Backend.MessageCodification exposing (..)
import Backend.Types exposing (..)
import Game.Types exposing (PlayerAction(..))
import Helpers exposing (httpErrorToString)
import Http exposing (Error, emptyBody, expectJson, expectString, expectWhatever, header, jsonBody, stringBody)
import Land exposing (Color(..))
import Snackbar exposing (toastError)
import Types exposing (AuthNetwork(..), AuthState, LoggedUser, LoginDialogStatus(..), Msg(..), PushEvent(..), PushSubscription, User(..))


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
                , expect = expectString (GetToken <| Just state)
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
            , levelPoints = 0
            , claimed = False
            , networks = [ Password ]
            , voted = []
            , awards = []
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
            expectString (GetToken <| Just state)
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
            expectString (GetToken Nothing)
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


getPushKey : Model -> Cmd Msg
getPushKey model =
    Http.get
        { url = model.baseUrl ++ "/push/key"
        , expect =
            expectString
                PushKey
        }


registerPush : Model -> ( PushSubscription, Bool ) -> Maybe String -> Cmd Msg
registerPush model ( subscription, enable ) jwt =
    Http.request
        { method =
            if enable then
                "POST"

            else
                "DELETE"
        , url = model.baseUrl ++ "/push/register"
        , headers =
            case jwt of
                Just passedJwt ->
                    [ header "authorization" ("Bearer " ++ passedJwt) ]

                Nothing ->
                    case model.jwt of
                        Just normalJwt ->
                            [ header "authorization" ("Bearer " ++ normalJwt) ]

                        Nothing ->
                            []
        , body =
            stringBody "application/json" subscription
        , expect = expectWhatever <| always Nop
        , timeout = Nothing
        , tracker = Nothing
        }


registerPushEvent : Model -> ( PushEvent, Bool ) -> Cmd Msg
registerPushEvent model ( event, enable ) =
    Http.request
        { method =
            if enable then
                "POST"

            else
                "DELETE"
        , url = model.baseUrl ++ "/push/register/events"
        , headers =
            case model.jwt of
                Just jwt ->
                    [ header "authorization" ("Bearer " ++ jwt) ]

                Nothing ->
                    []
        , body =
            stringBody "text/plain" <|
                case event of
                    GameStart ->
                        "game-start"

                    PlayerJoin ->
                        "player-join"
        , expect =
            expectString (GetToken Nothing)
        , timeout = Nothing
        , tracker = Nothing
        }
