module Backend.Encoding exposing (..)

import Game.Types exposing (TableStatus, Player, PlayerAction(..))
import Land exposing (Color, playerColor)
import Types exposing (..)
import Json.Encode exposing (object, string, list, null, Value, encode)


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


encodePlayerAction : Maybe String -> String -> PlayerAction -> String
encodePlayerAction jwt clientId action =
    encode 2 <|
        object <|
            List.concat
                [ [ ( "type", string <| actionToString action ) ]
                , [ ( "client", string clientId ) ]
                , case jwt of
                    Just jwt ->
                        [ ( "token", string jwt ) ]

                    Nothing ->
                        []
                , case actionPayload action of
                    Just payload ->
                        [ ( "payload", payload ) ]

                    Nothing ->
                        []
                ]


{-| Actions without parameters just use toString, otherwise do mapping
-}
actionToString : PlayerAction -> String
actionToString action =
    case action of
        Attack a b ->
            "Attack"

        Chat _ ->
            "Chat"

        _ ->
            toString action


actionPayload : PlayerAction -> Maybe Value
actionPayload action =
    case action of
        Attack from to ->
            Just <| list [ string from, string to ]

        Chat text ->
            Just <| string text

        _ ->
            Nothing
