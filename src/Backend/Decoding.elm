module Backend.Decoding exposing (..)

import Types exposing (LoggedUser)
import Tables exposing (Table(..))
import Game.Types exposing (TableStatus, Player)
import Land exposing (Color, playerColor)
import Json.Decode exposing (int, string, float, list, Decoder, map, succeed)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded)


loginDecoder : Decoder ()
loginDecoder =
    succeed ()


profileDecoder : Maybe String -> Decoder LoggedUser
profileDecoder existingToken =
    case existingToken of
        Just token ->
            decode LoggedUser
                |> required "name" string
                |> required "email" string
                |> required "picture" string
                |> optional "token" string token

        Nothing ->
            Json.Decode.map4 LoggedUser
                (Json.Decode.field "name" Json.Decode.string)
                (Json.Decode.field "email" Json.Decode.string)
                (Json.Decode.field "picture" Json.Decode.string)
                (Json.Decode.field "token" Json.Decode.string)


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
