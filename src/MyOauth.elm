module MyOauth exposing (authorizationEndpoint, authorize, init, profileEndpoint)

import Game.Types
import Http
import Json.Decode as Json
import Browser.Navigation
import Url exposing (Url)
import OAuth
import OAuth.AuthorizationCode exposing (AuthorizationResult(..))
import Task
import Types exposing (LoggedUser, Msg(..), MyOAuthModel)


profileEndpoint : String
profileEndpoint =
    "https://www.googleapis.com/oauth2/v1/userinfo"


authorizationEndpoint : Url
authorizationEndpoint =
    case Url.fromString "https://accounts.google.com/o/oauth2/v2/auth" of
        Just u ->
            u

        Nothing ->
            Debug.todo "bad auth url"


init : Browser.Navigation.Key -> Url -> ( MyOAuthModel, List (Cmd Msg) )
init key url =
    let
        oauth =
            { clientId = "1000163928607-54qf4s6gf7ukjoevlkfpdetepm59176n.apps.googleusercontent.com"
            , redirectUri = { url | query = Nothing, fragment = Nothing }
            , error = Nothing
            , token = Nothing
            , state = ""
            }
    in
        case OAuth.AuthorizationCode.parseCode url of
            Empty ->
                ( oauth, [] )

            Success { code, state } ->
                let
                    doJoin =
                        case Maybe.withDefault "" state of
                            "join" ->
                                True

                            _ ->
                                False
                in
                    ( oauth
                    , [ Browser.Navigation.replaceUrl key <| Url.toString oauth.redirectUri
                      , Task.perform (always <| Authenticate code doJoin) (Task.succeed ())
                        --Task.perform (always <| Types.GameCmd Game.Types.Join) (Task.succeed ())
                      ]
                    )

            Error { error, errorDescription, errorUri, state } ->
                ( { oauth | error = Just <| Maybe.withDefault "Unknown" errorDescription }
                , [ Browser.Navigation.replaceUrl key <| Url.toString oauth.redirectUri ]
                )


authorize : MyOAuthModel -> Bool -> Cmd Msg
authorize model doJoin =
    let
        authorization : OAuth.AuthorizationCode.Authorization
        authorization =
            { clientId = model.clientId
            , url = authorizationEndpoint
            , redirectUri = model.redirectUri
            , scope = [ "email", "profile" ]
            , state =
                case doJoin of
                    True ->
                        Just "join"

                    False ->
                        Nothing
            }
    in
        Browser.Navigation.load <|
            Url.toString <|
                OAuth.AuthorizationCode.makeAuthUrl authorization
