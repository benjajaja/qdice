module Backend.Encoding exposing (authStateEncoder, encodeAuthNetwork, encodePlayerAction, loginEncoder, myProfileUpdateEncoder, passwordEncoder, profileEncoder)

import Game.Types exposing (PlayerAction(..), actionToString)
import Json.Encode exposing (Value, bool, encode, int, list, null, object, string)
import MyProfile.Types exposing (MyProfileUpdate)
import Types exposing (..)


stringOrNull : Maybe String -> Value
stringOrNull s =
    case s of
        Just s_ ->
            string s_

        Nothing ->
            null


profileEncoder : LoggedUser -> Value
profileEncoder user =
    object
        [ ( "id", string user.id )
        , ( "name", string user.name )
        , ( "email", stringOrNull user.email )
        , ( "picture", string user.picture )
        ]


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

        Flag position ->
            Just <| int position

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

        None ->
            "none"

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
          , stringOrNull state.table
          )
        , ( "addTo"
          , stringOrNull state.addTo
          )
        ]


myProfileUpdateEncoder : MyProfileUpdate -> Value
myProfileUpdateEncoder update =
    object
        [ ( "name", stringOrNull update.name )
        , ( "email", stringOrNull update.email )
        , ( "picture", stringOrNull update.picture )
        , ( "password", stringOrNull update.password )
        , ( "passwordCheck", stringOrNull update.passwordCheck )
        ]


passwordEncoder : ( String, String ) -> Maybe String -> Value
passwordEncoder ( email, password ) passwordCheck =
    object
        [ ( "email", string email )
        , ( "password", string password )
        , ( "passwordCheck", stringOrNull passwordCheck )
        ]


loginEncoder : ( String, String ) -> Value
loginEncoder ( email, password ) =
    object
        [ ( "email", string email )
        , ( "password", string password )
        ]
