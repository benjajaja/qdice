module Backend.Decoding exposing (accknowledgeDecoder, colorDecoder, eliminationDecoder, eliminationReasonDecoder, gameStatusDecoder, globalDecoder, globalSettingsDecoder, landsUpdateDecoder, leaderBoardDecoder, mapNameDecoder, meDecoder, moveDecoder, playerGameStatsDecoder, playersDecoder, profileDecoder, rollDecoder, singleRollDecoder, tableDecoder, tableInfoDecoder, tableNameDecoder, tokenDecoder, userDecoder)

import Board.Types
import Game.Types exposing (Player, PlayerGameStats, TableStatus)
import Json.Decode exposing (Decoder, andThen, bool, fail, field, float, index, int, list, map, map2, map3, nullable, string, succeed)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Land exposing (Color, playerColor)
import LeaderBoard.Types exposing (LeaderBoardModel)
import Tables exposing (Table)
import Types exposing (LoggedUser, AuthNetwork(..), Profile)


tokenDecoder : Decoder String
tokenDecoder =
    string


userDecoder : Decoder LoggedUser
userDecoder =
    succeed LoggedUser
        |> required "id" string
        |> required "name" string
        |> required "email" (nullable string)
        |> required "picture" string
        |> required "points" int
        |> required "level" int
        |> required "claimed" bool
        |> required "networks" (list authNetworkDecoder)


authNetworkDecoder : Decoder AuthNetwork
authNetworkDecoder =
    map
        (\s ->
            case s of
                "google" ->
                    Google

                "telegram" ->
                    Telegram

                _ ->
                    Password
        )
        string


meDecoder : Decoder ( LoggedUser, String )
meDecoder =
    map2 (\a b -> ( a, b )) (index 0 userDecoder) (index 1 tokenDecoder)


tableNameDecoder : Decoder Table
tableNameDecoder =
    string



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
    succeed TableStatus
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
    succeed Player
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
    succeed PlayerGameStats
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
    succeed Game.Types.Roll
        |> required "from" singleRollDecoder
        |> required "to" singleRollDecoder


singleRollDecoder : Decoder Game.Types.RollPart
singleRollDecoder =
    succeed Game.Types.RollPart
        |> required "emoji" string
        |> required "roll" (list int)


moveDecoder : Decoder Game.Types.Move
moveDecoder =
    succeed Game.Types.Move
        |> required "from" string
        |> required "to" string


eliminationDecoder : Decoder Game.Types.Elimination
eliminationDecoder =
    succeed Game.Types.Elimination
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
    map2 (\a b -> ( a, b )) (field "settings" globalSettingsDecoder) (field "tables" (list tableInfoDecoder))


globalSettingsDecoder : Decoder Types.GlobalSettings
globalSettingsDecoder =
    succeed Types.GlobalSettings
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
    succeed Game.Types.TableInfo
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
    succeed Profile
        |> required "id" string
        |> required "name" string
        |> required "rank" int
        |> required "picture" string
        |> required "points" int
        |> required "level" int


leaderBoardDecoder : Decoder ( String, List Profile )
leaderBoardDecoder =
    map2 (\a b -> ( a, b ))
        (field "month" string)
        (field "top" (list profileDecoder))
