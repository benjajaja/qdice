module Board.PathCache exposing (addPointToString, addToDict, addToDictLines, landPointsString, line, pointToString, points, toKey)

import Board.Types exposing (..)
import Dict
import Helpers exposing (find)
import Land


points : PathCache -> Land.MapSize -> Land.Land -> String
points dict layout land =
    case Dict.get (toKey layout land) dict of
        Just path ->
            path

        Nothing ->
            Land.landPath layout land.cells |> landPointsString |> Debug.log "landPath"


line : PathCache -> Land.MapSize -> List Land.Land -> Land.Emoji -> Land.Emoji -> String
line dict layout lands from to =
    case Dict.get ("line_" ++ from ++ to) dict of
        Just linePoints ->
            linePoints

        Nothing ->
            lineConnection layout lands from to


addToDict : Land.MapSize -> List Land.Land -> Dict.Dict String String -> Dict.Dict String String
addToDict layout list dict =
    case list of
        f :: tail ->
            addToDict layout tail <|
                Dict.insert (toKey layout f) (Land.landPath layout f.cells |> landPointsString) dict

        [] ->
            dict


addToDictLines : Land.MapSize -> List Land.Land -> List ( Land.Emoji, Land.Emoji ) -> Dict.Dict String String -> Dict.Dict String String
addToDictLines layout lands connections dict =
    case connections of
        ( from, to ) :: tail ->
            addToDictLines layout lands tail <|
                Dict.insert ("line_" ++ from ++ to) (lineConnection layout lands from to) dict

        [] ->
            dict


toKey : Land.MapSize -> Land.Land -> String
toKey layout land =
    -- let
    -- layoutKey =
    -- String.fromFloat (Tuple.first layout.size)
    -- ++ ","
    -- ++ String.fromFloat (Tuple.second layout.size)
    -- ++ ","
    -- ++ String.fromFloat layout.padding
    -- in
    -- layoutKey ++ "_" ++ land.emoji
    land.emoji


landPointsString : List Land.Point -> String
landPointsString path =
    path |> List.foldl addPointToString ""


addPointToString : Land.Point -> String -> String
addPointToString point path =
    path ++ pointToString point ++ " "


pointToString : Land.Point -> String
pointToString ( x, y ) =
    (x |> String.fromFloat) ++ "," ++ (y |> String.fromFloat)


lineConnection : Land.MapSize -> List Land.Land -> Land.Emoji -> Land.Emoji -> String
lineConnection layout lands from to =
    let
        findLand =
            \emoji -> find (.emoji >> (==) emoji)

        ( x1f, y1f ) =
            case findLand from lands of
                Just land ->
                    Land.landCenter layout land.cells

                Nothing ->
                    Land.landCenter layout []

        ( x2f, y2f ) =
            case findLand to lands of
                Just land ->
                    Land.landCenter layout land.cells

                Nothing ->
                    Land.landCenter layout []
    in
    if x1f < x2f then
        "M "
            ++ String.fromFloat x1f
            ++ " "
            ++ String.fromFloat y1f
            ++ " L "
            ++ String.fromFloat x2f
            ++ " "
            ++ String.fromFloat y2f

    else
        "M "
            ++ String.fromFloat x1f
            ++ " "
            ++ String.fromFloat y1f
            ++ " C "
            ++ String.fromFloat x1f
            ++ " "
            ++ (String.fromFloat <| y1f - 10)
            ++ ", "
            ++ String.fromFloat x2f
            ++ " "
            ++ (String.fromFloat <| y2f - 10)
            ++ ", "
            ++ String.fromFloat x2f
            ++ " "
            ++ String.fromFloat y2f
