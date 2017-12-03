module Backend.Decoding exposing (..)

-- import Backend.Types exposing (..)

import Types exposing (LoggedUser)
import Tables exposing (Table(..))
import Game.Types exposing (TableStatus, Player)
import Land exposing (Color, playerColor)
import Json.Decode exposing (int, string, float, list, Decoder, map, succeed)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded)


-- decodeTableMessage : Table -> Decoder string
-- decodeTableMessage table =
--     Decoder string


loginDecoder : Decoder ()
loginDecoder =
    succeed ()


profileDecoder : Decoder LoggedUser
profileDecoder =
    Json.Decode.map3 LoggedUser
        (Json.Decode.field "name" Json.Decode.string)
        (Json.Decode.field "email" Json.Decode.string)
        (Json.Decode.field "picture" Json.Decode.string)


tableDecoder : Decoder TableStatus
tableDecoder =
    decode TableStatus
        |> required "players" (list playersDecoder)


playersDecoder : Decoder Player
playersDecoder =
    decode Player
        |> required "name" string
        |> required "color" colorDecoder


colorDecoder : Decoder Color
colorDecoder =
    map playerColor int


accknowledgeDecoder : Decoder ()
accknowledgeDecoder =
    succeed ()



-- decode Player
--     string
-- decode (list string)
--     |> required "players" string
