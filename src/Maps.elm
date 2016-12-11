port module Maps exposing (loadDefault, toCharList, consoleLogMap)

import Dict
import String
import Land exposing (Cells)
import Maps.Melchor exposing (map)
import Regex


type alias EmojiLand =
    { cells : Cells
    , emoji : String
    }


type alias Line =
    List ( ( Int, Int ), String )


port consoleDebug : String -> Cmd msg


emojiRegex : Regex.Regex
emojiRegex =
    Regex.regex "〿|\\u3000|[\\uD800-\\uDBFF][\\uDC00-\\uDFFF]"


consoleLogMap : Land.Map -> Cmd msg
consoleLogMap map =
    consoleDebug <| toEmojiString <| toCharList map


loadDefault : ( Land.Map, Cmd msg )
loadDefault =
    let
        raw =
            Maps.Melchor.map
                |> String.lines

        lines =
            raw
                |> List.indexedMap charRow

        widths : List Int
        widths =
            List.map
                ((List.map (fst >> fst))
                    >> List.maximum
                )
                lines
                |> List.map
                    (\l ->
                        case l of
                            Just a ->
                                a

                            Nothing ->
                                0
                    )
                |> Debug.log "widths"

        width =
            case List.maximum widths of
                Just w ->
                    w

                Nothing ->
                    0

        lands =
            List.map (List.filter (\t -> snd t /= Land.emptyEmoji && snd t /= "〿")) lines
                |> foldLines
                |> List.foldr dedupeEmojis []
                |> List.map (\l -> Land.Land l.cells Land.Neutral l.emoji False)

        cmd =
            consoleDebug <|
                "lines:"
                    ++ (String.join (String.fromChar '\n') <|
                            List.map (\l -> String.join "" <| List.map snd l) <|
                                lines
                       )
    in
        ( Land.Map lands width (List.length lines)
        , Cmd.batch
            [ cmd
              -- , consoleDebug <| "raw map: " ++ Maps.Melchor.map
            ]
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
                        List.map (\col -> Land.at lands ( col, row )) [1..map.width]
                            |> List.map indexSymbol
                            |> offsetCharRow row
                            |> trimRight
                    )
                    [1..map.height]


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
    fst <|
        List.foldr
            (\c ->
                \a ->
                    if snd a || c /= Land.emptyEmoji then
                        ( c :: fst a, True )
                    else
                        ( fst a, False )
            )
            ( [], False )
            line


symbolDict : Dict.Dict Int Char
symbolDict =
    List.indexedMap (,)
        [ '🍋'
        , '💩'
        , '🔥'
        , '😃'
        , '🐙'
        , '🐸'
        , '😺'
        , '🐵'
        , '🚩'
        , '🚬'
        , '🚶'
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
        , '👻'
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
