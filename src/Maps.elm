module Maps exposing (load, toCharList, consoleLogMap)

import Dict
import String
import Land exposing (Cells)
import Maps.Melchor
import Maps.Miño
import Regex
import Helpers exposing (..)
import Tables exposing (Table(..))


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


mapSourceString : Table -> MapSource
mapSourceString table =
    case table of
        Melchor ->
            Maps.Melchor.map

        Miño ->
            Maps.Miño.map


emojiRegex : Regex.Regex
emojiRegex =
    Regex.regex "〿|\\u3000|[\\uD800-\\uDBFF][\\uDC00-\\uDFFF]"


consoleLogMap : Land.Map -> Cmd msg
consoleLogMap map =
    consoleDebug <| toEmojiString <| toCharList map


load : Table -> ( Land.Map, Cmd msg )
load table =
    let
        raw =
            mapSourceString table
                |> String.lines

        lines : List Line
        lines =
            raw
                |> List.indexedMap charRow

        widths : List Int
        widths =
            List.map
                ((List.map (\l -> Tuple.first l |> Tuple.first)) >> List.maximum)
                lines
                |> List.map (Maybe.withDefault 0)

        width =
            List.maximum widths |> Maybe.withDefault 0

        lands =
            List.map (List.filter (\t -> Tuple.second t /= Land.emptyEmoji && Tuple.second t /= "〿")) lines
                |> foldLines
                |> List.foldr dedupeEmojis []
                |> List.map (\l -> Land.Land l.cells Land.Neutral l.emoji False 1)

        cmd =
            consoleDebug <|
                "Emoji map"
                    ++ (String.join (String.fromChar '\n') <|
                            List.map (\l -> String.join "" <| List.map Tuple.second l) <|
                                lines
                       )
    in
        ( Land.Map lands width (List.length lines)
        , cmd
        )


charRow : Int -> String -> Line
charRow row string =
    Regex.find Regex.All emojiRegex string
        |> List.map .match
        |> List.indexedMap (\col -> \c -> ( ( col + 1, row ), c ))


foldLines : List Line -> List EmojiLand
foldLines lines =
    List.foldr (\line -> \lands -> List.foldr foldChars lands line) [] lines


foldChars : ( ( Int, Int ), String ) -> List EmojiLand -> List EmojiLand
foldChars ( ( row, col ), char ) accum =
    if char == Land.emptyEmoji then
        accum
    else
        (EmojiLand [ Land.offsetToHex ( row, col ) ] char) :: accum


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
            Debug.crash "bad deduping"

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
                            |> List.map indexSymbol
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
    case row % 2 of
        0 ->
            "〿" :: line

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
    List.indexedMap (,)
        [ '🍋'
        , '👻'
        , '🔥'
        , '💰'
        , '🐙'
        , '🐸'
        , '😺'
        , '🐵'
        , '\x1F951'
        , '💎'
        , '⌛'
        , '🎩'
        , '👙'
        , '⚽'
        , '⛄'
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
        , '⛔'
        , '🍌'
        ]
        |> Dict.fromList


indexSymbol : Int -> String
indexSymbol i =
    case Dict.get i symbolDict of
        Just c ->
            String.fromChar c

        Nothing ->
            Land.emptyEmoji
