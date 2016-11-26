module Editor exposing (..)

import Dict
import Board
import Land


symbolDict : Dict.Dict Int Char
symbolDict =
    List.indexedMap (,)
        [ '💩'
        , '🍋'
        , '🔥'
        , '😃'
        , '🐙'
        , '🐸'
        , '☢'
        , '😺'
        , '🐵'
        , '❤'
        , '🚩'
        , '🚬'
        , '🚶'
        , '💎'
        , '⁉'
        , '⌛'
        , '☀'
        , '☁'
        , '☕'
        , '🎩'
        , '♨'
        , '👙'
        , '⚠'
        , '⚡'
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


indexSymbol : Int -> Char
indexSymbol i =
    case Dict.get i symbolDict of
        Just c ->
            c

        Nothing ->
            ' '
