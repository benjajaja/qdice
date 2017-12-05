module MyOauth exposing (..)

import Http
import Task
import Navigation
import Json.Decode as Json
import OAuth
import OAuth.AuthorizationCode
import Types exposing (MyOAuthModel, Msg(..), LoggedUser)


profileEndpoint : String
profileEndpoint =
    "https://www.googleapis.com/oauth2/v1/userinfo"


authorizationEndpoint : String
authorizationEndpoint =
    "https://accounts.google.com/o/oauth2/v2/auth"


init : Navigation.Location -> ( MyOAuthModel, List (Cmd Msg) )
init location =
    let
        oauth =
            { clientId = "1000163928607-54qf4s6gf7ukjoevlkfpdetepm59176n.apps.googleusercontent.com"
            , redirectUri = location.origin ++ location.pathname
            , error = Nothing
            , token = Nothing
            }
    in
        case OAuth.AuthorizationCode.parse location of
            Err (OAuth.Empty) ->
                ( oauth, [] )

            Ok { code } ->
                ( oauth
                , [ Navigation.modifyUrl oauth.redirectUri
                  , Task.perform (always <| Authenticate code) (Task.succeed ())
                  ]
                )

            Err (OAuth.OAuthErr err) ->
                ( { oauth | error = Just <| OAuth.showErrCode err.error }
                , [ Navigation.modifyUrl oauth.redirectUri ]
                )

            Err _ ->
                ( { oauth | error = Just "parsing error" }, [] )


authorize model =
    model
        ! [ OAuth.AuthorizationCode.authorize
                { clientId = model.oauth.clientId
                , redirectUri = model.oauth.redirectUri
                , responseType = OAuth.Code
                , scope = [ "email", "profile" ]
                , state = Nothing
                , url = authorizationEndpoint
                }
          ]
