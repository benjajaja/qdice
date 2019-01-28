module Maps exposing (consoleLogMap, emojisToMap, load, symbols, toCharList)

import Dict
import Helpers exposing (..)
import Land exposing (Cells)
import Maps.Sources exposing (mapSourceString)
import Regex
import String
import Tables exposing (Map, Table)


type alias MapSource =
    String


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


load : Map -> Land.Map
load map =
    emojisToMap <| mapSourceString map




emojisToMap : String -> Land.Map
emojisToMap raw =
    let
        lines : List Line
        lines =
            raw
                |> String.lines
                |> List.indexedMap charRow

        widths : List Int
        widths =
            List.map
                (List.map (\l -> Tuple.first l |> Tuple.first) >> List.maximum)
                lines
                |> List.map (Maybe.withDefault 0)

        width =
            List.maximum widths |> Maybe.withDefault 0

        lands =
            List.map (List.filter isEmptyEmoji) lines
                |> foldLines
                |> List.foldr dedupeEmojis []
                |> List.map (\l -> Land.Land l.cells Land.Neutral l.emoji 1)
    in
    Land.Map lands width (List.length lines)


charRow : Int -> String -> Line
charRow row string =
    Regex.find emojiRegex string
        |> List.map .match
        |> List.indexedMap (\col -> \c -> ( ( col + (modBy 2 row), row ), c ))


foldLines : List Line -> List EmojiLand
foldLines lines =
    List.foldr (\line -> \lands -> List.foldr foldChars lands line) [] lines


foldChars : ( ( Int, Int ), String ) -> List EmojiLand -> List EmojiLand
foldChars ( ( row, col ), char ) accum =
    if char == Land.emptyEmoji then
        accum

    else
        EmojiLand [ Land.offsetToHex ( row, col ) ] char :: accum


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
            List.filter (\l -> l.color /= Land.Editor) map.lands
                |> List.reverse
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


indexSymbol : Int -> String
indexSymbol i =
    case Dict.get i symbolDict of
        Just c ->
            String.fromChar c

        Nothing ->
            Land.emptyEmoji
