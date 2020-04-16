module Land exposing (Cells, Color(..), Emoji, Land, Map, MapSize, Point, allSides, append, areNeighbours, at, cellBorder, cellCenter, cellCubicCoords, cellOnBorder, cellToKey, centerPoint, concat, defaultSide, emptyEmoji, findLand, firstFreeBorder, firstFreeBorder_, hasAttackableNeighbours, hasCell, hasFreeBorder, indexAt, isBordering, isCellOnLandBorder, isNothing, landBorders, landCenter, landPath, leftSide, nextBorders, nextBorders_, oppositeSide, playerColor, randomPlayerColor, rightSide)

import Array exposing (Array)
import Bitwise
import Dict exposing (Dict)
import Helpers exposing (find, findIndex, resultCombine)
import Hex exposing (Hex, Point, borderLeftCorner, cellCubicCoords, hexToOffset, offsetToHex)
import Hexagons.Hex as HH exposing (Direction)
import List
import Random


type alias Cells =
    List Hex


type alias Point =
    Hex.Point


type alias Emoji =
    String


type alias Land =
    { cells : Cells
    , color : Color
    , emoji : Emoji
    , points : Int
    , capital : Bool
    }


type alias MapSize =
    ( Float, Float )


type alias Map =
    { name : String
    , lands : List Land
    , width : Int
    , height : Int
    , adjacencyKeys : Dict Emoji Int
    , adjacency : Array (Array Bool)
    , waterConnections : List ( Emoji, Emoji )
    }


type alias Border =
    ( Hex, Direction )


type Color
    = Neutral
    | Red
    | Green
    | Blue {- 3 -}
    | Yellow
    | Magenta
    | Cyan
    | Orange {- 7 -}
    | Black
    | Brown


cellToKey : Hex -> String
cellToKey cell =
    case cell of
        HH.IntCubeHex ( a, b, c ) ->
            String.join ","
                [ String.fromInt a
                , String.fromInt b
                , String.fromInt c
                ]

        HH.FloatCubeHex ( a, b, c ) ->
            String.join ","
                [ String.fromFloat a
                , String.fromFloat b
                , String.fromFloat c
                ]

        HH.AxialHex ( a, b ) ->
            String.join ","
                [ String.fromInt a
                , String.fromInt b
                ]


emptyEmoji : String
emptyEmoji =
    "\u{3000}"


landPath : MapSize -> Cells -> List Point
landPath layout cells =
    landBorders cells |> List.map (borderLeftCorner <| Hex.myLayout layout)


landCenter : MapSize -> Cells -> Point
landCenter layout cells =
    case cells of
        [] ->
            ( -1, -1 )

        list ->
            centerPoint layout list


centerPoint : MapSize -> Cells -> Point
centerPoint layout cells =
    let
        lx =
            List.map (Hex.center (Hex.myLayout layout) >> Tuple.first) cells

        ly =
            List.map (Hex.center (Hex.myLayout layout) >> Tuple.second) cells
    in
    ( List.sum lx / toFloat (List.length lx)
    , List.sum ly / toFloat (List.length ly)
    )


cellCenter : MapSize -> Hex -> Point
cellCenter layout hex =
    Hex.center (Hex.myLayout layout) hex


cellCubicCoords : Hex -> ( Int, Int, Int )
cellCubicCoords hex =
    Hex.cellCubicCoords hex


isBordering : Map -> Land -> Land -> Result String Bool
isBordering map a b =
    Result.map2
        Tuple.pair
        (Dict.get
            a.emoji
            map.adjacencyKeys
            |> Result.fromMaybe (a.emoji ++ " not in matrix")
        )
        (Dict.get
            b.emoji
            map.adjacencyKeys
            |> Result.fromMaybe (b.emoji ++ " not in matrix")
        )
        |> Result.andThen
            (\( indexA, indexB ) ->
                Array.get indexA map.adjacency
                    |> Maybe.andThen (Array.get indexB)
                    |> Result.fromMaybe "not it matrix"
            )


isBitSet : Int -> Int -> Bool
isBitSet index bits =
    let
        mask =
            Bitwise.shiftLeftBy index 1
    in
    Bitwise.and mask bits == mask



-- List.any
-- (\( ta, tb ) ->
-- (ta == a.emoji && tb == b.emoji)
-- || (ta == b.emoji && tb == a.emoji)
-- )
-- map.extraAdjacency
-- || List.any (isCellOnLandBorder b) a.cells


isCellOnLandBorder : Land -> Hex -> Bool
isCellOnLandBorder land hex =
    List.any (areNeighbours hex) land.cells


areNeighbours : Hex -> Hex -> Bool
areNeighbours a b =
    let
        flipped =
            \c -> \d -> isBorderOnSide a d c
    in
    List.any (flipped b) allSides


append : Map -> Land -> Map
append map land =
    { map | lands = List.append [ land ] map.lands }


{-| return index of coord in map
-}
at : List Land -> ( Int, Int ) -> Maybe Land
at lands coord =
    let
        hex =
            offsetToHex coord

        cb : Hex -> Land -> Bool
        cb aHex land =
            List.any (\h -> Hex.eq h aHex) land.cells
    in
    find (cb hex) lands


indexAt : List Land -> ( Int, Int ) -> Int
indexAt lands coord =
    let
        hex =
            offsetToHex coord

        cb : Hex -> Land -> Bool
        cb aHex land =
            List.any (\h -> Hex.eq h aHex) land.cells
    in
    findIndex (cb hex) lands


{-| concat all cells in map to a single neutral land
-}
concat : Map -> Land
concat map =
    let
        hexes : Cells
        hexes =
            List.map (\l -> l.cells) map.lands |> List.concat
    in
    case hexes of
        [] ->
            Land [] Neutral emptyEmoji 0 False

        _ ->
            Land hexes Neutral emptyEmoji 0 False


playerColor : Int -> Color
playerColor i =
    if i == -1 then
        Neutral

    else
        case i of
            1 ->
                Red

            2 ->
                Blue

            3 ->
                Green

            4 ->
                Yellow

            5 ->
                Magenta

            6 ->
                Cyan

            7 ->
                Orange

            8 ->
                Black

            9 ->
                Brown

            _ ->
                Neutral


randomPlayerColor : (Color -> a) -> Cmd a
randomPlayerColor v =
    Random.int 1 7 |> Random.map playerColor |> Random.generate v


allSides : List Direction
allSides =
    [ HH.NW, HH.NE, HH.E, HH.SE, HH.SW, HH.W ]


cellBorder : Hex -> Direction -> ( Hex, Direction )
cellBorder hex border =
    ( hex, border )


defaultSide : Direction
defaultSide =
    HH.NW


landBorders : Cells -> List Border
landBorders cells =
    case cells of
        [ one ] ->
            List.map (cellBorder one) (List.reverse allSides)

        _ ->
            case firstFreeBorder cells of
                Nothing ->
                    -- Set of cells must have some outer borders!
                    []

                Just ( coord, side ) ->
                    nextBorders cells coord ( coord, side ) side [ ( coord, side ) ]


nextBorders : Cells -> Hex -> Border -> Direction -> List Border -> List Border
nextBorders cells coord origin side accum =
    nextBorders_ cells coord origin side [] 100000


nextBorders_ : Cells -> Hex -> Border -> Direction -> List Border -> Int -> List Border
nextBorders_ cells coord origin side accum fuse =
    let
        current =
            ( coord, side )
    in
    if (Hex.eq coord <| Tuple.first origin) && Tuple.second origin == side && List.length accum > 1 then
        current :: accum

    else
        case cellOnBorder coord side cells of
            Just c ->
                nextBorders_ cells c origin (rightSide (oppositeSide side)) accum (fuse - 1)

            Nothing ->
                nextBorders_ cells coord origin (rightSide side) (current :: accum) (fuse - 1)


rightSide : Direction -> Direction
rightSide side =
    case side of
        HH.NW ->
            HH.NE

        HH.NE ->
            HH.E

        HH.E ->
            HH.SE

        HH.SE ->
            HH.SW

        HH.SW ->
            HH.W

        HH.W ->
            HH.NW


leftSide : Direction -> Direction
leftSide side =
    case side of
        HH.NW ->
            HH.W

        HH.NE ->
            HH.NW

        HH.E ->
            HH.NE

        HH.SE ->
            HH.E

        HH.SW ->
            HH.SE

        HH.W ->
            HH.SW


oppositeSide : Direction -> Direction
oppositeSide =
    rightSide >> rightSide >> rightSide


hasCell : Cells -> Hex -> Bool
hasCell cells coord =
    List.any (Hex.eq coord) cells


firstFreeBorder : Cells -> Maybe Border
firstFreeBorder cells =
    firstFreeBorder_ cells cells


firstFreeBorder_ : Cells -> Cells -> Maybe Border
firstFreeBorder_ accum cells =
    case accum of
        [] ->
            Nothing

        hd :: tail ->
            case hasFreeBorder cells hd allSides of
                Just a ->
                    Just ( hd, a )

                Nothing ->
                    firstFreeBorder_ tail cells


hasFreeBorder : Cells -> Hex -> List Direction -> Maybe Direction
hasFreeBorder cells coord sides =
    case sides of
        [] ->
            Nothing

        hd :: tl ->
            if cellOnBorder coord hd cells |> isNothing then
                Just hd

            else
                hasFreeBorder cells coord tl


isNothing : Maybe a -> Bool
isNothing a =
    case a of
        Nothing ->
            True

        Just _ ->
            False


cellOnBorder : Hex -> Direction -> Cells -> Maybe Hex
cellOnBorder coord side cells =
    case cells of
        hd :: tl ->
            if isBorderOnSide coord side hd then
                Just hd

            else if List.length cells == 1 then
                Nothing

            else
                cellOnBorder coord side tl

        _ ->
            Nothing


isBorderOnSide : Hex -> Direction -> Hex -> Bool
isBorderOnSide coord side other =
    if Hex.eq coord other then
        False

    else
        isBorderOnSideCube coord side other


{-| offset implementation - too messy but probably faster
-}
isBorderOnSideCube : Hex -> Direction -> Hex -> Bool
isBorderOnSideCube coord side other =
    let
        ( x, y ) =
            hexToOffset coord

        ( x_, y_ ) =
            hexToOffset other

        even =
            modBy 2 y == 0
    in
    case side of
        HH.W ->
            y_ == y && x_ == x - 1

        HH.E ->
            y_ == y && x_ == x + 1

        HH.NW ->
            if even then
                x_ == x - 1 && y_ == y - 1

            else
                x_ == x && y_ == y - 1

        HH.NE ->
            if even then
                x_ == x && y_ == y - 1

            else
                x_ == x + 1 && y_ == y - 1

        HH.SW ->
            if even then
                x_ == x - 1 && y_ == y + 1

            else
                x_ == x && y_ == y + 1

        HH.SE ->
            if even then
                x_ == x && y_ == y + 1

            else
                x_ == x + 1 && y_ == y + 1


findLand : Emoji -> List Land -> Maybe Land
findLand emoji lands =
    find (\l -> l.emoji == emoji) lands


hasAttackableNeighbours : Map -> Land -> Result String Bool
hasAttackableNeighbours map land =
    map.lands
        |> List.map (canAttack map land)
        |> resultCombine
        |> Result.map (List.any identity)


canAttack : Map -> Land -> Land -> Result String Bool
canAttack map source target =
    if source.points > 1 && target.color /= source.color then
        isBordering map source target

    else
        Ok False
