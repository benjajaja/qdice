module Backend.HttpCommands exposing (authenticate, deleteAccount, games, getPushKey, leaderBoard, loadGlobalSettings, loadMe, profile, register, registerPush, registerPushEvent, toastHttpError, updateAccount, updatePassword)

import Backend.Decoding exposing (..)
import Backend.Encoding exposing (..)
import Backend.MessageCodification exposing (..)
import Backend.Types exposing (..)
import Game.Types exposing (PlayerAction(..))
import Helpers exposing (httpErrorToString)
import Http exposing (Error, emptyBody, expectJson, expectString, expectStringResponse, expectWhatever, header, jsonBody, stringBody)
import Land exposing (Color(..))
import MyProfile.Types exposing (MyProfileUpdate)
import Snackbar exposing (toastError)
import Tables exposing (Table)
import Types exposing (AuthNetwork(..), AuthState, GamesMsg(..), GamesSubRoute(..), LeaderboardMsg(..), LoginDialogStatus(..), Msg(..), PushEvent(..), PushSubscription, User(..), UserId)
import Url.Builder exposing (int)


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
                , expect = expectString <| GetToken state.table
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
                , expect = expectString <| GetToken state.table
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


leaderBoard : Model -> Int -> Cmd Msg
leaderBoard model page =
    Http.get
        { url = Url.Builder.relative [ model.baseUrl, "leaderboard" ] [ Url.Builder.int "page" page ]
        , expect = expectJson (LeaderboardMsg << GetLeaderboard) leaderBoardDecoder
        }


profile : Model -> UserId -> Cmd Msg
profile model id =
    Http.get
        { url = model.baseUrl ++ "/profile/" ++ id
        , expect = expectJson GetOtherProfile profileDecoder
        }


register : Types.Model -> String -> Maybe Table -> ( Types.Model, Cmd Msg )
register model name joinTable =
    let
        loginProfile =
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
    in
    ( { model | showLoginDialog = LoginHide }
    , Http.post
        { url = model.backend.baseUrl ++ "/register"
        , body =
            jsonBody <| profileEncoder loginProfile
        , expect =
            expectString (GetToken joinTable)
        }
    )


updateAccount : Model -> MyProfileUpdate -> Cmd Msg
updateAccount model newProfile =
    Http.request
        { method = "PUT"
        , headers =
            case model.jwt of
                Just jwt ->
                    [ header "authorization" ("Bearer " ++ jwt) ]

                Nothing ->
                    []
        , url = model.baseUrl ++ "/me"
        , body =
            jsonBody <| myProfileUpdateEncoder newProfile
        , expect =
            expectStringWithError GetUpdateProfile
        , timeout = Nothing
        , tracker = Nothing
        }


expectStringWithError : (Result String String -> msg) -> Http.Expect msg
expectStringWithError toMsg =
    expectStringResponse toMsg <|
        \response ->
            case response of
                Http.BadStatus_ metadata body ->
                    Err body

                Http.GoodStatus_ metadata body ->
                    Ok body

                _ ->
                    Err "Network problem."


updatePassword : Model -> ( String, String ) -> Maybe String -> Cmd Msg
updatePassword model ( email, password ) passwordCheck =
    Http.request
        { method = "PUT"
        , headers =
            case model.jwt of
                Just jwt ->
                    [ header "authorization" ("Bearer " ++ jwt) ]

                Nothing ->
                    []
        , url = model.baseUrl ++ "/me/password"
        , body = jsonBody <| passwordEncoder ( email, password ) passwordCheck
        , expect =
            expectStringWithError GetUpdateProfile
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
            expectStringWithError GetUpdateProfile
        , timeout = Nothing
        , tracker = Nothing
        }


games : Model -> GamesSubRoute -> Cmd Msg
games model sub =
    Http.get
        { url =
            Url.Builder.relative
                (List.concat
                    [ [ model.baseUrl, "games" ]
                    , case sub of
                        GamesOfTable table ->
                            [ table ]

                        GameId table id ->
                            [ table, String.fromInt id ]

                        AllGames ->
                            []
                    ]
                )
                []
        , expect = expectJson (GamesMsg << GetGames sub) gamesDecoder
        }
