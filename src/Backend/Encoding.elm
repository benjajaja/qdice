module Backend.Encoding exposing (actionPayload, authStateEncoder, encodeAuthNetwork, encodeJwt, encodePlayerAction, playerEncoder, profileEncoder)

import Game.Types exposing (Player, PlayerAction(..), actionToString)
import Json.Encode exposing (Value, bool, encode, list, null, object, string)
import Types exposing (..)


playerEncoder : Player -> Value
playerEncoder user =
    object
        [ ( "name", string user.name )
        ]


profileEncoder : LoggedUser -> Value
profileEncoder user =
    object
        [ ( "id", string user.id )
        , ( "name", string user.name )
        , ( "email"
          , case user.email of
                Just email ->
                    string email

                Nothing ->
                    null
          )
        , ( "picture", string user.picture )
        ]


encodeJwt : String -> String
encodeJwt =
    string >> encode 2


encodePlayerAction : Maybe String -> String -> PlayerAction -> Result String String
encodePlayerAction jwt clientId action =
    Ok <|
        encode 2 <|
            object <|
                List.concat
                    [ [ ( "type", string <| actionToString action ) ]
                    , [ ( "client", string clientId ) ]
                    , case jwt of
                        Just jwt_ ->
                            [ ( "token", string jwt_ ) ]

                        Nothing ->
                            []
                    , case actionPayload action of
                        Just payload ->
                            [ ( "payload", payload ) ]

                        Nothing ->
                            []
                    ]


actionPayload : PlayerAction -> Maybe Value
actionPayload action =
    case action of
        Attack from to ->
            Just <| list string [ from, to ]

        Chat text ->
            Just <| string text

        ToggleReady ready ->
            Just <| bool ready

        _ ->
            Nothing


encodeAuthNetwork : AuthNetwork -> String
encodeAuthNetwork network =
    case network of
        Google ->
            "google"

        Reddit ->
            "reddit"

        Password ->
            "password"

        Telegram ->
            "telegram"


authStateEncoder : AuthState -> Value
authStateEncoder state =
    object
        [ ( "network"
          , string <| encodeAuthNetwork state.network
          )
        , ( "table"
          , case state.table of
                Just table ->
                    string table

                Nothing ->
                    null
          )
        ]
