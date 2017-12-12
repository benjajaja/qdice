module Backend.Decoding exposing (..)

import Types exposing (LoggedUser)
import Tables exposing (Table(..))
import Game.Types exposing (TableStatus, Player)
import Board.Types
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
        |> required "playerSlots" int
        |> required "status" gameStatusDecoder
        |> required "turnIndex" int
        |> required "turnStarted" int
        |> required "lands" (list landsUpdateDecoder)


playersDecoder : Decoder Player
playersDecoder =
    decode Player
        |> required "id" string
        |> required "name" string
        |> required "color" colorDecoder
        |> required "picture" string


landsUpdateDecoder : Decoder Board.Types.LandUpdate
landsUpdateDecoder =
    decode Board.Types.LandUpdate
        |> required "emoji" string
        |> required "color" colorDecoder
        |> required "points" int


colorDecoder : Decoder Color
colorDecoder =
    map playerColor int


gameStatusDecoder : Decoder Game.Types.GameStatus
gameStatusDecoder =
    map
        (\s ->
            case s of
                "PAUSED" ->
                    Game.Types.Paused

                "PLAYING" ->
                    Game.Types.Playing

                "FINISHED" ->
                    Game.Types.Finished

                _ ->
                    Game.Types.Paused
        )
        string


accknowledgeDecoder : Decoder ()
accknowledgeDecoder =
    succeed ()


rollDecoder : Decoder Game.Types.Roll
rollDecoder =
    decode Game.Types.Roll
        |> required "from" singleRollDecoder
        |> required "to" singleRollDecoder


singleRollDecoder : Decoder Game.Types.RollPart
singleRollDecoder =
    decode Game.Types.RollPart
        |> required "emoji" string
        |> required "roll" (list int)
