module Backend.Decoding exposing (..)

import Types exposing (LoggedUser)
import Tables exposing (Table(..), decodeTable)
import Game.Types exposing (TableStatus, Player, PlayerGameStats)
import Board.Types
import Land exposing (Color, playerColor)
import Json.Decode exposing (int, string, float, bool, list, Decoder, map, succeed, field)
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
        |> required "gameStart" int
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
        |> required "out" bool
        |> required "derived" playerGameStatsDecoder
        |> required "reserveDice" int


playerGameStatsDecoder : Decoder PlayerGameStats
playerGameStatsDecoder =
    decode PlayerGameStats
        |> required "totalLands" int
        |> required "connectedLands" int
        |> required "currentDice" int


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


moveDecoder : Decoder Game.Types.Move
moveDecoder =
    decode Game.Types.Move
        |> required "from" string
        |> required "to" string


eliminationDecoder : Decoder Game.Types.Elimination
eliminationDecoder =
    decode Game.Types.Elimination
        |> required "player" playersDecoder
        |> required "position" int
        |> required "reason" eliminationReasonDecoder


eliminationReasonDecoder : Decoder Game.Types.EliminationReason
eliminationReasonDecoder =
    decode Game.Types.EliminationReason
        |> required "type" eliminationTypeTagDecoder


eliminationTypeTagDecoder : Decoder Game.Types.EliminationType
eliminationTypeTagDecoder =
    map
        (\s ->
            case s of
                "☠" ->
                    Game.Types.Death

                "💤" ->
                    Game.Types.Out

                "🏆" ->
                    Game.Types.Win

                _ ->
                    Game.Types.Death
        )
        string


globalDecoder : Decoder ( Types.GlobalSettings, List Game.Types.TableInfo )
globalDecoder =
    Json.Decode.map2 (,) (field "settings" globalSettingsDecoder) (field "tables" (list tableInfoDecoder))


globalSettingsDecoder : Decoder Types.GlobalSettings
globalSettingsDecoder =
    decode Types.GlobalSettings


tableTagDecoder : Decoder Table
tableTagDecoder =
    let
        convert : String -> Decoder Table
        convert string =
            case decodeTable string of
                Just table ->
                    Json.Decode.succeed table

                Nothing ->
                    Json.Decode.fail <| "cannot decode table name: " ++ string
    in
        string |> Json.Decode.andThen convert


tableInfoDecoder : Decoder Game.Types.TableInfo
tableInfoDecoder =
    decode Game.Types.TableInfo
        |> required "name" tableTagDecoder
        |> required "playerSlots" int
        |> required "playerCount" int
        |> required "status" gameStatusDecoder
        |> required "landCount" int
        |> required "stackSize" int
