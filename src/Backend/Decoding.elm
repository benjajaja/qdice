module Backend.Decoding exposing (..)

import Types exposing (LoggedUser, Profile)
import Tables exposing (Table)
import Game.Types exposing (TableStatus, Player, PlayerGameStats)
import Board.Types
import LeaderBoard.Types exposing (LeaderBoardModel)
import Land exposing (Color, playerColor)
import Json.Decode exposing (int, string, float, bool, list, Decoder, map, map2, map3, index, succeed, fail, field, nullable, andThen)
import Json.Decode.Pipeline exposing (decode, required, optional, hardcoded)


tokenDecoder : Decoder String
tokenDecoder =
    string


userDecoder : Decoder LoggedUser
userDecoder =
    decode LoggedUser
        |> required "id" string
        |> required "name" string
        |> required "email" (nullable string)
        |> required "picture" string
        |> required "points" int
        |> required "level" int


meDecoder : Decoder ( LoggedUser, String )
meDecoder =
    map2 (,) (index 0 userDecoder) (index 1 tokenDecoder)


tableNameDecoder : Decoder Table
tableNameDecoder = string
    -- map decodeTable string
    --     |> andThen
    --         (\t ->
    --             case t of
    --                 Just table ->
    --                     succeed table

    --                 Nothing ->
    --                     fail "unknown table"
    --         )


tableDecoder : Decoder TableStatus
tableDecoder =
    decode TableStatus
        |> required "players" (list playersDecoder)
        |> required "mapName" mapNameDecoder
        |> required "playerSlots" int
        |> required "status" gameStatusDecoder
        |> required "gameStart" int
        |> required "turnIndex" int
        |> required "turnStart" int
        |> required "lands" (list landsUpdateDecoder)
        |> required "roundCount" int
        |> required "canFlag" bool
        |> required "watchCount" int


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
        |> required "points" int
        |> required "level" int
        |> required "flag" (nullable int)


playerGameStatsDecoder : Decoder PlayerGameStats
playerGameStatsDecoder =
    decode PlayerGameStats
        |> required "totalLands" int
        |> required "connectedLands" int
        |> required "currentDice" int
        |> required "position" int
        |> required "score" int


landsUpdateDecoder : Decoder Board.Types.LandUpdate
landsUpdateDecoder =
    map3 Board.Types.LandUpdate (index 0 string) (index 1 colorDecoder) (index 2 int)


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
        |> required "score" int
        |> required "reason" eliminationReasonDecoder


eliminationReasonDecoder : Decoder Game.Types.EliminationReason
eliminationReasonDecoder =
    field "type" string
        |> andThen
            (\t ->
                case t of
                    "☠" ->
                        map2 Game.Types.ReasonDeath
                            (field "player" playersDecoder)
                            (field "points" int)

                    "💤" ->
                        field "turns" int |> Json.Decode.map Game.Types.ReasonOut

                    "🏆" ->
                        field "turns" int |> Json.Decode.map Game.Types.ReasonWin

                    "🏳" ->
                        field "flag" int |> Json.Decode.map Game.Types.ReasonFlag

                    _ ->
                        Json.Decode.fail <| "unknown elimination type: " ++ t
            )


globalDecoder : Decoder ( Types.GlobalSettings, List Game.Types.TableInfo )
globalDecoder =
    map2 (,) (field "settings" globalSettingsDecoder) (field "tables" (list tableInfoDecoder))


globalSettingsDecoder : Decoder Types.GlobalSettings
globalSettingsDecoder =
    decode Types.GlobalSettings
        |> required "gameCountdownSeconds" int
        |> required "maxNameLength" int
        |> required "turnSeconds" int


-- tableTagDecoder : Decoder Table
-- tableTagDecoder =
--     let
--         convert : String -> Decoder Table
--         convert string =
--             case decodeTable string of
--                 Just table ->
--                     Json.Decode.succeed table

--                 Nothing ->
--                     Json.Decode.fail <| "cannot decode table name: " ++ string
--     in
--         string |> Json.Decode.andThen convert

mapNameDecoder : Decoder Tables.Map
mapNameDecoder =
    map Tables.decodeMap string
        |> andThen
            (\m ->
                case m of
                    Just map ->
                        succeed map

                    Nothing ->
                        fail "unknown map"
            )

tableInfoDecoder : Decoder Game.Types.TableInfo
tableInfoDecoder =
    decode Game.Types.TableInfo
        |> required "name" string
        |> required "mapName" mapNameDecoder
        |> required "playerSlots" int
        |> required "playerCount" int
        |> required "watchCount" int
        |> required "status" gameStatusDecoder
        |> required "landCount" int
        |> required "stackSize" int
        |> required "points" int


profileDecoder : Decoder Profile
profileDecoder =
    decode Profile
        |> required "id" string
        |> required "name" string
        |> required "rank" int
        |> required "picture" string
        |> required "points" int
        |> required "level" int


leaderBoardDecoder : Decoder ( String, List Profile )
leaderBoardDecoder =
    map2 (,)
        (field "month" string)
        (field "top" (list profileDecoder))
