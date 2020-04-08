module Maps exposing (consoleLogMap, emptyMap, load, symbols, toCharList)

import Array exposing (Array)
import Dict exposing (Dict)
import Helpers exposing (combine, consoleDebug, resultCombine)
import Hex
import Land exposing (Cells, Emoji)
import Maps.Sources exposing (mapSourceString)
import Regex
import String
import Tables exposing (Map(..), encodeMap)


type alias EmojiLand =
    { cells : Cells
    , emoji : String
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
    emojisToMap (encodeMap map) <| mapSourceString map


emojisToMap : String -> String -> Result String Land.Map
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
                |> List.map (\l -> Land.Land l.cells Land.Neutral l.emoji 1)

        keys : Result String (Dict Emoji Int)
        keys =
            rawLines
                |> List.filter (String.startsWith "indices:")
                |> List.head
                |> Maybe.map
                    (String.slice (String.length "indices:") -1
                        -- >> String.split ""
                        >> (Regex.find emojiRegex
                                >> List.map .match
                           )
                        >> List.indexedMap (\i -> \emoji -> ( emoji, i ))
                        >> Dict.fromList
                    )
                |> Result.fromMaybe "No adjacency indices in map"

        rowSize : Result String Int
        rowSize =
            Result.map (Dict.keys >> List.length) keys

        toBool : Int -> Bool
        toBool f =
            if f == 1 then
                True

            else
                False

        decodeMatrixRow : List Bool -> Int -> Result String (Array Bool)
        decodeMatrixRow acc row =
            if row > 1 then
                decodeMatrixRow
                    ((row |> remainderBy 2 |> toBool) :: acc)
                    (toFloat row / 2 |> floor)

            else
                Ok <| Array.fromList acc

        adjacency : Result String (Array (Array Bool))
        adjacency =
            rawLines
                |> List.filter (String.startsWith "matrix:")
                |> List.head
                |> Result.fromMaybe "no matrix in emoji source"
                |> Result.andThen
                    (String.slice (String.length "matrix:") -1
                        >> String.split ","
                        >> List.map
                            (String.split ""
                                >> List.map
                                    (String.toInt
                                        >> Result.fromMaybe "cannot parse bit"
                                        >> Result.map
                                            (\bit ->
                                                if bit == 1 then
                                                    True

                                                else
                                                    False
                                            )
                                    )
                                >> resultCombine
                                >> Result.map Array.fromList
                            )
                        >> resultCombine
                        >> Result.map Array.fromList
                    )

        -- adjacency : Result String (Array (Array Bool))
        -- adjacency =
        -- rawLines
        -- |> List.filter (String.startsWith "matrix:")
        -- |> List.head
        -- |> Result.fromMaybe "no matrix in emoji source"
        -- |> Result.andThen
        -- (String.slice (String.length "matrix:") -1
        -- >> String.split ","
        -- >> List.map
        -- ((String.toInt
        -- >> Result.fromMaybe "bad matrix row"
        -- )
        -- >> Result.andThen (decodeMatrixRow [])
        -- )
        -- >> resultCombine
        -- >> Result.map Array.fromList
        -- )
    in
    Result.map3
        (\a b c ->
            Land.Map name
                lands
                a
                realHeight
                b
                c
                extraAdjacency
        )
        realWidth
        keys
        adjacency


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
