module Backend.HttpCommands exposing (authenticate, deleteAccount, leaderBoard, loadGlobalSettings, loadMe, login, toastHttpError, updateAccount)

import Backend.Decoding exposing (..)
import Backend.Encoding exposing (..)
import Backend.MessageCodification exposing (..)
import Backend.Types exposing (..)
import Game.Types exposing (Player, PlayerAction(..))
import Helpers exposing (httpErrorToString)
import Http
import Land exposing (Color(..))
import Snackbar exposing (toastError)
import Tables exposing (Table)
import Types exposing (AuthNetwork(..), AuthState, LoggedUser, LoginDialogStatus(..), Msg(..), User(..))


toastHttpError : Http.Error -> Cmd Msg
toastHttpError err =
    toastError (httpErrorToString err) (httpErrorToString err)


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
                        , url = model.baseUrl ++ "/add-login/" ++ encodeAuthNetwork state.network
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


login : Types.Model -> String -> ( Types.Model, Cmd Msg )
login model name =
    let
        profile =
            { name = name
            , id = "💩"
            , email = Nothing
            , picture = ""
            , points = 0
            , level = 0
            , claimed = False
            , networks = [ Password ]
            }

        request =
            Http.request
                { method = "POST"
                , url = model.backend.baseUrl ++ "/register"
                , headers = []
                , body =
                    Http.jsonBody <| profileEncoder profile
                , expect =
                    Http.expectJson <| tokenDecoder
                , timeout = Nothing
                , withCredentials = False
                }

        state =
            { network = Password, table = model.game.table, addTo = Nothing }
    in
    ( { model | showLoginDialog = LoginHide }
    , Http.send (Types.GetToken <| Just state) request
    )


updateAccount : Model -> LoggedUser -> Cmd Msg
updateAccount model profile =
    Http.send (GetToken Nothing) <|
        Http.request
            { method = "PUT"
            , headers =
                case model.jwt of
                    Just jwt ->
                        [ Http.header "authorization" ("Bearer " ++ jwt) ]

                    Nothing ->
                        []
            , url = model.baseUrl ++ "/profile"
            , body =
                Http.jsonBody <| profileEncoder profile
            , expect =
                Http.expectJson <| tokenDecoder
            , timeout = Nothing
            , withCredentials = False
            }


deleteAccount : (Result Http.Error String -> Msg) -> Model -> User -> Cmd Msg
deleteAccount msg model user =
    case user of
        Logged logged ->
            Http.send msg <|
                Http.request
                    { method = "DELETE"
                    , headers =
                        case model.jwt of
                            Just jwt ->
                                [ Http.header "authorization" ("Bearer " ++ jwt) ]

                            Nothing ->
                                []
                    , url = model.baseUrl ++ "/me"
                    , body =
                        Http.emptyBody
                    , expect =
                        Http.expectString
                    , timeout = Nothing
                    , withCredentials = False
                    }

        _ ->
            toastError "Error: not logged in" ""
