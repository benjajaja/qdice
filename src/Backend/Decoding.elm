module Backend.Decoding exposing (..)

import Types exposing (LoggedUser)
import Tables exposing (Table(..))
import Game.Types exposing (TableStatus, Player)
import Land exposing (Color, playerColor)
import Json.Decode exposing (int, string, float, list, Decoder, map, succeed)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded)


tokenDecoder : Decoder String
tokenDecoder =
    string


profileDecoder : Decoder LoggedUser
profileDecoder =
    decode LoggedUser
        |> required "id" string
        |> required "name" string
        |> required "email" string
        |> required "picture" string


tableDecoder : Decoder TableStatus
tableDecoder =
    decode TableStatus
        |> required "players" (list playersDecoder)


playersDecoder : Decoder Player
playersDecoder =
    decode Player
        |> required "id" string
        |> required "name" string
        |> required "color" colorDecoder


colorDecoder : Decoder Color
colorDecoder =
    map playerColor int


accknowledgeDecoder : Decoder ()
accknowledgeDecoder =
    succeed ()
