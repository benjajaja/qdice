module Backend.Decoding exposing (authStateDecoder, commentDecoder, commentsDecoder, eliminationsDecoder, gamesDecoder, globalDecoder, leaderBoardDecoder, meDecoder, moveDecoder, otherProfileDecoder, playersDecoder, profileDecoder, rollDecoder, stringDecoder, tableDecoder, tableInfoDecoder, turnDecoder)

import Backend.Types exposing (TableMessage(..))
import Board.Types
import Game.Types exposing (Award, Player, PlayerGameStats, TableParams, TableStatus)
import Games.Types exposing (..)
import Helpers exposing (triple)
import Iso8601
import Json.Decode exposing (Decoder, andThen, bool, fail, field, index, int, lazy, list, map, map2, map3, map4, maybe, nullable, string, succeed)
import Json.Decode.Pipeline exposing (required)
import Land exposing (Color, playerColor)
import Tables exposing (Table)
import Types exposing (AuthNetwork(..), AuthState, Comment, CommentAuthor, CommentKind(..), GlobalQdice, LeaderBoardResponse, LoggedUser, OtherProfile, Preferences, Profile, ProfileStats, PushEvent(..), Replies(..))


stringDecoder : Decoder String
stringDecoder =
    string


userDecoder : Decoder LoggedUser
userDecoder =
    succeed LoggedUser
        |> required "id" string
        |> required "name" string
        |> required "email" (nullable string)
        |> required "picture" string
        |> required "points" int
        |> required "rank" int
        |> required "level" int
        |> required "levelPoints" int
        |> required "claimed" bool
        |> required "networks" (list authNetworkDecoder)
        |> required "voted" (list string)
        |> required "awards" (list awardDecoder)


authNetworkDecoder : Decoder AuthNetwork
authNetworkDecoder =
    map
        (\s ->
            case s of
                "google" ->
                    Google

                "telegram" ->
                    Telegram

                "reddit" ->
                    Reddit

                "password" ->
                    Password

                _ ->
                    None
        )
        string


authStateDecoder : Decoder AuthState
authStateDecoder =
    succeed AuthState
        |> required "network" authNetworkDecoder
        |> required "table" (nullable string)
        |> required "addTo" (nullable string)


preferencesDecoder : Decoder Preferences
preferencesDecoder =
    succeed Preferences
        |> required "pushSubscribed" (list pushEventDecoder)


awardDecoder : Decoder Award
awardDecoder =
    succeed Award
        |> required "type" string
        |> required "position" int
        |> required "timestamp" string


pushEventDecoder : Decoder PushEvent
pushEventDecoder =
    map
        (\s ->
            case s of
                "game-start" ->
                    GameStart

                "player-join" ->
                    PlayerJoin

                _ ->
                    GameStart
        )
        string


meDecoder : Decoder ( LoggedUser, String, Preferences )
meDecoder =
    map3 (\a b c -> ( a, b, c )) (index 0 userDecoder) (index 1 stringDecoder) (index 2 preferencesDecoder)


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
        |> required "watchCount" int
        |> required "currentGame" (maybe int)


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
        |> required "awards" (list awardDecoder)
        |> required "flag" (nullable int)
        |> required "ready" bool


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
    map4 Board.Types.LandUpdate
        (index 0 string)
        (index 1 colorDecoder)
        (index 2 int)
        (index 3
            (map
                (\i ->
                    if i == -1 then
                        Nothing

                    else
                        Just <| Land.Capital i
                )
                int
            )
        )


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
        |> required "turnStart" int
        |> required "players" (list playersDecoder)


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


eliminationsDecoder : Decoder ( List Game.Types.Elimination, List Game.Types.Player )
eliminationsDecoder =
    succeed Tuple.pair
        |> required "eliminations" (list eliminationDecoder)
        |> required "players" (list playersDecoder)


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
                        map2 Game.Types.ReasonFlag
                            (field "flag" int)
                            (field "under"
                                (nullable <|
                                    map2 Tuple.pair
                                        (field "player" playersDecoder)
                                        (field "points" int)
                                )
                            )

                    _ ->
                        Json.Decode.fail <| "unknown elimination type: " ++ t
            )


globalDecoder : Decoder GlobalQdice
globalDecoder =
    succeed GlobalQdice
        |> required "settings" globalSettingsDecoder
        |> required "tables" (list tableInfoDecoder)
        |> required "leaderboard" leaderBoardTopDecoder
        |> required "version" string


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
                    Ok map ->
                        succeed map

                    Err err ->
                        fail err
            )


tableInfoDecoder : Decoder Game.Types.TableInfo
tableInfoDecoder =
    succeed Game.Types.TableInfo
        |> required "name" string
        |> required "mapName" mapNameDecoder
        |> required "playerSlots" int
        |> required "startSlots" int
        |> required "playerCount" int
        |> required "watchCount" int
        |> required "status" gameStatusDecoder
        |> required "landCount" int
        |> required "stackSize" int
        |> required "points" int
        |> required "params" tableParamsDecoder


tableParamsDecoder : Decoder TableParams
tableParamsDecoder =
    succeed TableParams
        |> required "noFlagRounds" int
        |> required "botLess" bool
        |> required "startingCapitals" bool
        |> required "readySlots" (nullable int)
        |> required "turnSeconds" (nullable int)


profileDecoder : Decoder Profile
profileDecoder =
    succeed Profile
        |> required "id" string
        |> required "name" string
        |> required "rank" int
        |> required "picture" string
        |> required "points" int
        |> required "level" int
        |> required "levelPoints" int
        |> required "awards" (list awardDecoder)


leaderBoardTopDecoder : Decoder ( String, List Profile )
leaderBoardTopDecoder =
    map2 Tuple.pair
        (field "month" string)
        (field "top" (list profileDecoder))


leaderBoardDecoder : Decoder LeaderBoardResponse
leaderBoardDecoder =
    succeed LeaderBoardResponse
        |> required "month" string
        |> required "board" (list profileDecoder)
        |> required "page" int


gamesDecoder : Decoder (List Game)
gamesDecoder =
    list gameDecoder


gameDecoder : Decoder Game
gameDecoder =
    succeed Game
        |> required "id" int
        |> required "tag" string
        |> required "gameStart" Iso8601.decoder
        |> required "players" (list gamePlayerDecoder)
        |> required "events" (list gameEventDecoder)
        |> required "lands"
            (list <|
                map3 triple (index 0 string) (index 1 colorDecoder) (index 2 int)
            )


gamePlayerDecoder : Decoder GamePlayer
gamePlayerDecoder =
    succeed GamePlayer
        |> required "id" string
        |> required "name" string
        |> required "picture" string
        |> required "color" colorDecoder
        |> required "bot" bool


gameEventDecoder : Decoder GameEvent
gameEventDecoder =
    field "type" string
        |> andThen
            (\t ->
                case t of
                    "Start" ->
                        succeed Games.Types.Start

                    "Chat" ->
                        succeed Games.Types.Chat
                            |> required "user" shortPlayerDecoder
                            |> required "message" string

                    "Attack" ->
                        succeed Games.Types.Attack
                            |> required "player" shortPlayerDecoder
                            |> required "from" string
                            |> required "to" string

                    "Roll" ->
                        succeed Games.Types.Roll
                            |> required "fromRoll" (list int)
                            |> required "toRoll" (list int)

                    "EndTurn" ->
                        succeed Games.Types.EndTurn
                            |> required "player" shortPlayerDecoder

                    "TickTurnOut" ->
                        succeed Games.Types.TickTurnOut

                    "TickTurnOver" ->
                        succeed Games.Types.TickTurnOver
                            |> required "sitPlayerOut" bool

                    "TickTurnAllOut" ->
                        succeed Games.Types.TickTurnAllOut

                    "SitOut" ->
                        succeed Games.Types.SitOut
                            |> required "player" shortPlayerDecoder

                    "SitIn" ->
                        succeed Games.Types.SitIn
                            |> required "player" shortPlayerDecoder

                    "ToggleReady" ->
                        succeed Games.Types.ToggleReady
                            |> required "player" shortPlayerDecoder
                            |> required "ready" bool

                    "Flag" ->
                        succeed Games.Types.Flag
                            |> required "player" shortPlayerDecoder

                    "EndGame" ->
                        succeed Games.Types.EndGame
                            |> required "winner" (nullable shortPlayerDecoder)
                            |> required "turnCount" int

                    _ ->
                        succeed Games.Types.Start
             -- fail <| "Unknown game event type: " ++ t
            )


shortPlayerDecoder : Decoder ShortGamePlayer
shortPlayerDecoder =
    succeed ShortGamePlayer
        |> required "id" string
        |> required "name" string


otherProfileDecoder : Decoder OtherProfile
otherProfileDecoder =
    map2 (\a b -> ( a, b ))
        (field "profile" profileDecoder)
        (field "stats" profileStatsDecoder)


profileStatsDecoder : Decoder ProfileStats
profileStatsDecoder =
    succeed ProfileStats
        |> required "games" (list gameRefDecoder)
        |> required "gamesWon" int
        |> required "gamesPlayed" int


gameRefDecoder : Decoder GameRef
gameRefDecoder =
    succeed GameRef
        |> required "id" int
        |> required "tag" string
        |> required "gameStart" Iso8601.decoder


turnDecoder : Decoder Game.Types.TurnInfo
turnDecoder =
    succeed Game.Types.TurnInfo
        |> required "turnIndex" int
        |> required "turnStart" int
        |> required "roundCount" int
        |> required "giveDice" (nullable giveDiceDecoder)
        |> required "players" (list playersDecoder)
        |> required "lands" (list landsUpdateDecoder)


giveDiceDecoder : Decoder ( Player, Int )
giveDiceDecoder =
    map2 Tuple.pair
        (index 0 playersDecoder)
        (index 1 int)


commentsDecoder : Decoder (List Comment)
commentsDecoder =
    list commentDecoder


commentDecoder : Decoder Comment
commentDecoder =
    succeed Comment
        |> required "id" int
        |> required "kind" kindDecoder
        |> required "author" authorDecoder
        |> required "timestamp" int
        |> required "body" string
        |> required "replies" (map Replies (list (lazy (\_ -> commentDecoder))))


kindDecoder : Decoder CommentKind
kindDecoder =
    map2
        (\kind kindId ->
            case kind of
                "user" ->
                    Just <| UserWall kindId ""

                "games" ->
                    Maybe.map (\i -> GameComments i "") (String.toInt kindId)

                "tables" ->
                    Just <| TableComments kindId

                "comments" ->
                    Maybe.map (\i -> ReplyComments i "") (String.toInt kindId)

                _ ->
                    Nothing
        )
        (index 0 string)
        (index 1 string)
        |> andThen
            (\k ->
                case k of
                    Just ok ->
                        succeed ok

                    Nothing ->
                        fail "unknown comment kind"
            )


authorDecoder : Decoder CommentAuthor
authorDecoder =
    succeed CommentAuthor
        |> required "id" int
        |> required "name" string
        |> required "picture" string
