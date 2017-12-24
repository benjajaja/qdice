module Board.PathCache exposing (..)

import Dict
import Board.Types exposing (..)
import Land


createPathCache : Land.Map -> (Land.Layout -> Land.Land -> String)
createPathCache map =
    let
        ( layout, _, _ ) =
            getLayout map

        dict : Dict.Dict String String
        dict =
            addToDict Dict.empty layout map.lands
    in
        (\layout ->
            \land ->
                case Dict.get (toKey layout land) dict of
                    Just path ->
                        path

                    Nothing ->
                        Land.landPath layout land.cells |> landPointsString |> Debug.log "pathCache miss"
        )


addToDict dict layout list =
    case list of
        f :: tail ->
            addToDict (Dict.insert (toKey layout f) (Land.landPath layout f.cells |> landPointsString) dict) layout tail

        [] ->
            dict


toKey : Land.Layout -> Land.Land -> String
toKey layout land =
    (toString layout)
        ++ (List.foldl (++) "" <| List.map Land.cellToKey land.cells)


landPointsString : List Land.Point -> String
landPointsString path =
    path |> List.foldl addPointToString ""


addPointToString : Land.Point -> String -> String
addPointToString point path =
    path ++ (pointToString point) ++ " "


pointToString : Land.Point -> String
pointToString ( x, y ) =
    (x |> toString) ++ "," ++ (y |> toString)
