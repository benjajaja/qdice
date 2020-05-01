module Maps exposing (consoleLogMap, emptyMap, load, mapFromTable, symbols, toCharList)

import Array
import Dict
import Helpers exposing (combine, consoleDebug)
import Hex
import Land exposing (Cells, Emoji)
import Maps.Sources exposing (mapAdjacency, mapSourceString)
import Regex
import String
import Tables exposing (Map(..), Table, encodeMap)


type alias EmojiLand =
    { cells : Cells
    , emoji : String
    }


type alias EmojiMap =
    { name : String
    , lands : List Land.Land
    , width : Int
    , height : Int
    , waterConnections : List ( Emoji, Emoji )
    }


type alias LineColRow =
    ( Int, Int )


type alias Line =
    List ( LineColRow, String )


emojiRegex : Regex.Regex
emojiRegex =
    Regex.fromString "〿|ｯ|\\u3000|[\\uD800-\\uDBFF][\\uDC00-\\uDFFF]"
        |> Maybe.withDefault Regex.never


consoleLogMap : Land.Map -> Cmd msg
consoleLogMap map =
    consoleDebug <| toEmojiString <| toCharList map


load : Map -> Result String Land.Map
load map =
    let
        emojiMap =
            emojisToMap (encodeMap map) <| mapSourceString map

        ( indices, matrix ) =
            mapAdjacency map
    in
    Result.map
        (\{ name, lands, width, height, waterConnections } ->
            Land.Map name
                lands
                width
                height
                (indices |> Dict.fromList)
                (matrix
                    |> List.map
                        (List.map
                            (\i ->
                                case i of
                                    1 ->
                                        True

                                    _ ->
                                        False
                            )
                            >> Array.fromList
                        )
                    |> Array.fromList
                )
                waterConnections
        )
        emojiMap


emojisToMap : String -> String -> Result String EmojiMap
emojisToMap name raw =
    let
        rawLines : List String
        rawLines =
            String.lines raw

        water : Maybe String
        water =
            rawLines
                |> List.filter (String.startsWith "water:")
                |> List.head

        extraAdjacency : List ( Land.Emoji, Land.Emoji )
        extraAdjacency =
            case water of
                Just extra ->
                    String.split "," extra
                        |> List.map
                            (Regex.find emojiRegex
                                >> List.map .match
                            )
                        |> List.foldl emojisToTuples []

                Nothing ->
                    []

        lines : List Line
        lines =
            rawLines
                |> List.filter
                    (\line ->
                        if
                            String.startsWith "water:" line
                                || String.startsWith "indices:" line
                                || String.startsWith "matrix:" line
                        then
                            False

                        else
                            True
                    )
                |> List.indexedMap charRow

        widths : Maybe (List Int)
        widths =
            List.map
                (List.map (Tuple.first >> Tuple.first) >> List.maximum)
                lines
                |> List.filter ((/=) Nothing)
                |> combine

        realWidth : Result String Int
        realWidth =
            Maybe.andThen List.maximum widths
                |> Result.fromMaybe "Could not get width of emoji map"

        realHeight =
            List.length lines

        lands : List Land.Land
        lands =
            List.map (List.filter isEmptyEmoji) lines
                |> foldLines
                |> List.foldr dedupeEmojis []
                |> List.map (\l -> Land.Land l.cells Land.Neutral l.emoji 1 Nothing)
    in
    Result.map
        (\a ->
            EmojiMap name
                lands
                a
                realHeight
                extraAdjacency
        )
        realWidth


emojisToTuples : List Emoji -> List ( Emoji, Emoji ) -> List ( Emoji, Emoji )
emojisToTuples emojis acc =
    case emojis of
        [ a, b ] ->
            ( a, b ) :: acc

        _ ->
            acc


charRow : Int -> String -> Line
charRow row string =
    Regex.find emojiRegex string
        |> List.map .match
        |> List.indexedMap (\col -> \c -> ( ( col + modBy 2 row, row ), c ))


foldLines : List Line -> List EmojiLand
foldLines lines =
    List.foldr (\line -> \lands -> List.foldr foldChars lands line) [] lines


foldChars : ( ( Int, Int ), String ) -> List EmojiLand -> List EmojiLand
foldChars ( ( col, row ), char ) accum =
    if char == Land.emptyEmoji then
        accum

    else
        EmojiLand [ Hex.offsetToHex ( col, row ) ] char :: accum


isEmptyEmoji : ( a, String ) -> Bool
isEmptyEmoji t =
    Tuple.second t
        |> (\c -> c /= Land.emptyEmoji && c /= "〿" && c /= "ｯ")


dedupeEmojis : EmojiLand -> List EmojiLand -> List EmojiLand
dedupeEmojis land list =
    case findEmojiLand land.emoji list of
        Just ( match, rest ) ->
            { match | cells = List.append land.cells match.cells } :: rest

        Nothing ->
            land :: list


findEmojiLand : String -> List EmojiLand -> Maybe ( EmojiLand, List EmojiLand )
findEmojiLand emoji list =
    case
        List.partition (\l -> l.emoji == emoji) list
    of
        ( [ one ], rest ) ->
            Just ( one, rest )

        ( head :: tail, rest ) ->
            --Debug.todo "bad deduping"
            Nothing

        _ ->
            Nothing


toCharList : Land.Map -> List (List String)
toCharList map =
    let
        lands =
            map.lands |> List.reverse
    in
    case lands of
        [] ->
            [ [] ]

        hd :: _ ->
            List.map
                (\row ->
                    List.map (\col -> Land.at lands ( col, row )) (List.range 1 map.width)
                        |> List.map (Maybe.map .emoji >> Maybe.withDefault "\u{3000}")
                        |> offsetCharRow row
                        |> trimRight
                )
                (List.range 1 map.height)


toEmojiString : List (List String) -> String
toEmojiString charList =
    List.map (String.join "") charList
        |> String.join (String.fromChar '\n')


offsetCharRow : Int -> List String -> List String
offsetCharRow row line =
    case modBy 2 row of
        0 ->
            "ｯ" :: line

        _ ->
            line


trimRight : List String -> List String
trimRight line =
    Tuple.first <|
        List.foldr
            (\c ->
                \a ->
                    if Tuple.second a || c /= Land.emptyEmoji then
                        ( c :: Tuple.first a, True )

                    else
                        ( Tuple.first a, False )
            )
            ( [], False )
            line


symbolDict : Dict.Dict Int Char
symbolDict =
    List.indexedMap (\a b -> ( a, b ))
        [ '🍋'
        , '👻'
        , '🔥'
        , '💰'
        , '🐙'
        , '🐸'
        , '😺'
        , '🐵'
        , '\u{1F951}'
        , '💎'
        , '⌛'
        , '🎩'
        , '👙'
        , '⚽'
        , '🏰'
        , '⭐'
        , '🌙'
        , '🌴'
        , '🌵'
        , '🍀'
        , '💥'
        , '🍒'
        , '🍩'
        , '🍷'
        , '🍺'
        , '🍏'
        , '🎵'
        , '🐟'
        , '🐧'
        , '🐰'
        , '🍉'
        , '👀'
        , '👍'
        , '👑'
        , '💊'
        , '💋'
        , '💣'
        , '💧'
        , '💀'
        , '🌎'
        , '🐊'
        , '✊'
        , '💃'
        , '🍌'
        ]
        |> Dict.fromList


symbols : List String
symbols =
    Dict.values symbolDict
        |> List.map String.fromChar


emptyMap : Land.Map
emptyMap =
    Land.Map "empty" [] 40 40 Dict.empty Array.empty []


mapFromTable : Table -> Result String Map
mapFromTable table =
    case table of
        "Planeta" ->
            Ok Planeta

        "España" ->
            Ok Serrano

        "Lagos" ->
            Ok DeLucía

        "Polo" ->
            Ok Melchor

        "Arabia" ->
            Ok Sabicas

        "Europa" ->
            Ok Montoya

        "Twitter" ->
            Ok Planeta

        "Seguirilla" ->
            Ok Cepero

        _ ->
            Tables.decodeMap table
