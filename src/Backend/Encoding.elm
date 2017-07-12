module Backend.Encoding exposing (..)

import Game.Types exposing (TableStatus, Player)
import Land exposing (Color, playerColor)
import Json.Encode exposing (object, string, Value)


playerEncoder : Player -> Value
playerEncoder user =
    object
        [ ( "name", string user.name )
        ]
