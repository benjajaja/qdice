module Board.PathCache exposing (addPointToString, addToDict, addToDictLines, center, landPointsString, line, pointToString, points)

import Board.Types exposing (..)
import Dict
import Helpers exposing (combine, find)
import Land


points : PathCache -> Land.Emoji -> Maybe String
points dict emoji =
    Dict.get emoji dict


line : PathCache -> Land.Emoji -> Land.Emoji -> Maybe String
line dict from to =
    Dict.get ("line_" ++ from ++ to) dict


center : PathCache -> Land.Emoji -> Maybe ( Float, Float )
center dict emoji =
    Dict.get ("center_" ++ emoji) dict
        |> Maybe.andThen
            (String.split ","
                >> List.map String.toFloat
                >> combine
            )
        |> Maybe.andThen
            (\list ->
                case list of
                    a :: b :: _ ->
                        Just ( a, b )

                    _ ->
                        Nothing
            )


addToDict : Land.MapSize -> List Land.Land -> Dict.Dict String String -> Dict.Dict String String
addToDict layout list dict =
    case list of
        f :: tail ->
            addToDict layout tail <|
                Dict.insert f.emoji (Land.landPath layout f.cells |> landPointsString) <|
                    Dict.insert ("center_" ++ f.emoji)
                        (Land.landCenter layout f.cells
                            |> (\( a, b ) -> String.fromFloat a ++ "," ++ String.fromFloat b)
                        )
                        dict

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
