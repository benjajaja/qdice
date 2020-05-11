port module MyOauth exposing (authorize, init, networkIdName, saveToken)

import Backend.Decoding exposing (authStateDecoder)
import Backend.Encoding exposing (authStateEncoder)
import Backend.HttpCommands exposing (authenticate)
import Backend.Types
import Browser.Navigation
import Json.Decode exposing (decodeString, errorToString)
import Json.Encode exposing (encode)
import OAuth.AuthorizationCode exposing (AuthorizationResult(..))
import Snackbar exposing (toastError)
import Types exposing (AuthNetwork(..), AuthState, Msg(..), MyOAuthModel)
import Url exposing (Protocol(..), Url)


port saveToken : Maybe String -> Cmd msg


authorizationEndpoint : AuthNetwork -> Maybe ( Url, String )
authorizationEndpoint network =
    case network of
        Reddit ->
            Just
                ( { protocol = Https
                  , host = "www.reddit.com"
                  , port_ = Nothing
                  , path = "/api/v1/authorize"
                  , query = Nothing
                  , fragment = Nothing
                  }
                , "FjcCKkabynWNug"
                )

        Google ->
            Just
                ( { protocol = Https
                  , host = "accounts.google.com"
                  , port_ = Nothing
                  , path = "/o/oauth2/v2/auth"
                  , query = Nothing
                  , fragment = Nothing
                  }
                , "1000163928607-54qf4s6gf7ukjoevlkfpdetepm59176n.apps.googleusercontent.com"
                )

        Github ->
            Just
                ( { protocol = Https
                  , host = "github.com"
                  , port_ = Nothing
                  , path = "/login/oauth/authorize"
                  , query = Nothing
                  , fragment = Nothing
                  }
                , "acbcad9ce3615b6fb44d"
                )

        Telegram ->
            Nothing

        Password ->
            Nothing


init : Browser.Navigation.Key -> Url -> Backend.Types.Model -> ( MyOAuthModel, List (Cmd Msg) )
init key url backend =
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
                              , authenticate backend code authState
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
    case authorizationEndpoint state.network of
        Just ( url, clientId ) ->
            let
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

        Nothing ->
            toastError "Unknown auth method" <| networkIdName state.network


networkIdName : AuthNetwork -> String
networkIdName network =
    case network of
        Google ->
            "google"

        Github ->
            "github"

        Reddit ->
            "reddit"

        Telegram ->
            "telegram"

        Password ->
            "password"
