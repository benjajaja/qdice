module Board.PathCache exposing (addPointToString, addToDict, landPointsString, pointToString, points, toKey)

import Board.Types exposing (..)
import Dict
import Land


points : PathCache -> Land.Layout -> Land.Land -> String
points dict layout land =
    case Dict.get (toKey layout land) dict of
        Just path ->
            path

        Nothing ->
            Land.landPath layout land.cells |> landPointsString


addToDict : Dict.Dict String String -> Land.Layout -> List Land.Land -> Dict.Dict String String
addToDict dict layout list =
    case list of
        f :: tail ->
            addToDict (Dict.insert (toKey layout f) (Land.landPath layout f.cells |> landPointsString) dict) layout tail

        [] ->
            dict


toKey : Land.Layout -> Land.Land -> String
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
