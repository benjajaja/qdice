module Backend.Encoding exposing (..)

import Game.Types exposing (TableStatus, Player)
import Land exposing (Color, playerColor)
import Types exposing (..)
import Json.Encode exposing (object, string, Value)


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
        , ( "email", string user.email )
        , ( "picture", string user.picture )
        ]
