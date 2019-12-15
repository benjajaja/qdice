port module MyOauth exposing (authorize, init, saveToken)

import Backend.Decoding exposing (authStateDecoder)
import Backend.Encoding exposing (authStateEncoder)
import Browser.Navigation
import Game.Types
import Http
import Json.Decode exposing (decodeString, errorToString)
import Json.Encode exposing (encode)
import OAuth
import OAuth.AuthorizationCode exposing (AuthorizationResult(..))
import Snackbar exposing (toastError)
import Task
import Types exposing (AuthNetwork(..), AuthState, LoggedUser, Msg(..), MyOAuthModel)
import Url exposing (Protocol(..), Url)


port saveToken : Maybe String -> Cmd msg


authorizationEndpoint : AuthNetwork -> ( Url, String )
authorizationEndpoint network =
    case network of
        Reddit ->
            ( { protocol = Https
              , host = "www.reddit.com"
              , port_ = Nothing
              , path = "/api/v1/authorize"
              , query = Nothing
              , fragment = Nothing
              }
            , "FjcCKkabynWNug"
            )

        _ ->
            ( { protocol = Https
              , host = "accounts.google.com"
              , port_ = Nothing
              , path = "/o/oauth2/v2/auth"
              , query = Nothing
              , fragment = Nothing
              }
            , "1000163928607-54qf4s6gf7ukjoevlkfpdetepm59176n.apps.googleusercontent.com"
            )


init : Browser.Navigation.Key -> Url -> ( MyOAuthModel, List (Cmd Msg) )
init key url =
    let
        oauth =
            { redirectUri = { url | query = Nothing, fragment = Nothing, path = "/" }
            , error = Nothing
            , token = Nothing
            , state = ""
            }
    in
    case OAuth.AuthorizationCode.parseCode url of
        Empty ->
            ( oauth, [] )

        Success { code, state } ->
            case state of
                Nothing ->
                    ( oauth, [ toastError "Logn provider did not comply, try another" "empty state" ] )

                Just state_ ->
                    case decodeString authStateDecoder state_ of
                        Ok authState ->
                            ( oauth
                            , [ Browser.Navigation.replaceUrl key <| Url.toString oauth.redirectUri
                              , Task.perform
                                    (always <| Authenticate code authState)
                                    (Task.succeed ())
                              ]
                            )

                        Err err ->
                            ( oauth
                            , [ toastError "Could not read your login" <| errorToString err ]
                            )

        Error { error, errorDescription, errorUri, state } ->
            ( { oauth | error = Just <| Maybe.withDefault "Unknown" errorDescription }
            , [ Browser.Navigation.replaceUrl key <| Url.toString oauth.redirectUri ]
            )


authorize : MyOAuthModel -> AuthState -> Cmd Msg
authorize model state =
    let
        ( url, clientId ) =
            authorizationEndpoint state.network

        stateString : String
        stateString =
            encode 0 <| authStateEncoder state

        authorization : OAuth.AuthorizationCode.Authorization
        authorization =
            { clientId = clientId
            , url = url
            , redirectUri = model.redirectUri
            , scope =
                case state.network of
                    Reddit ->
                        [ "identity" ]

                    _ ->
                        [ "email", "profile" ]
            , state = Just stateString
            }
    in
    Browser.Navigation.load <|
        Url.toString <|
            OAuth.AuthorizationCode.makeAuthorizationUrl authorization
