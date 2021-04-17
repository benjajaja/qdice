module Land exposing (Capital, Cells, Color(..), DiceSkin(..), Emoji, Land, LandUpdate, Map, MapSize, Point, at, emptyEmoji, findLand, hasAttackableNeighbours, isBordering, landCenter, landPath, playerColor)

import Array exposing (Array)
import Dict exposing (Dict)
import Helpers exposing (find, resultCombine)
import Hex exposing (Direction(..), Hex, Point, borderLeftCorner, hexToOffset, offsetToHex)
import List
import Tables exposing (MapName)


type DiceSkin
    = Normal
    | Bot


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
    , diceSkin : DiceSkin
    , capital : Maybe Capital
    }


type alias LandUpdate =
    { emoji : Emoji
    , color : Color
    , points : Int
    , capital : Maybe Capital
    }


type alias Capital =
    { count : Int
    }


type alias MapSize =
    ( Float, Float )


type alias Map =
    { name : MapName
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


allSides : List Direction
allSides =
    [ NW, NE, E, SE, SW, W ]


cellBorder : Hex -> Direction -> ( Hex, Direction )
cellBorder hex border =
    ( hex, border )


landBorders : Cells -> List Border
landBorders cells =
    case cells of
        [ one ] ->
            List.map (cellBorder one) (List.reverse allSides)

        _ ->
            case firstFreeBorder cells cells of
                Nothing ->
                    -- Set of cells must have some outer borders!
                    []

                Just ( coord, side ) ->
                    nextBorders cells coord ( coord, side ) side [] 100000


nextBorders : Cells -> Hex -> Border -> Direction -> List Border -> Int -> List Border
nextBorders cells coord origin side accum fuse =
    let
        current =
            ( coord, side )
    in
    if (Hex.eq coord <| Tuple.first origin) && Tuple.second origin == side && List.length accum > 1 then
        current :: accum

    else
        case cellOnBorder coord side cells of
            Just c ->
                nextBorders cells c origin (rightSide (oppositeSide side)) accum (fuse - 1)

            Nothing ->
                nextBorders cells coord origin (rightSide side) (current :: accum) (fuse - 1)


rightSide : Direction -> Direction
rightSide side =
    case side of
        NW ->
            NE

        NE ->
            E

        E ->
            SE

        SE ->
            SW

        SW ->
            W

        W ->
            NW


oppositeSide : Direction -> Direction
oppositeSide =
    rightSide >> rightSide >> rightSide


firstFreeBorder : Cells -> Cells -> Maybe Border
firstFreeBorder accum cells =
    case accum of
        [] ->
            Nothing

        hd :: tail ->
            case hasFreeBorder cells hd allSides of
                Just a ->
                    Just ( hd, a )

                Nothing ->
                    firstFreeBorder tail cells


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
        W ->
            y_ == y && x_ == x - 1

        E ->
            y_ == y && x_ == x + 1

        NW ->
            if even then
                x_ == x - 1 && y_ == y - 1

            else
                x_ == x && y_ == y - 1

        NE ->
            if even then
                x_ == x && y_ == y - 1

            else
                x_ == x + 1 && y_ == y - 1

        SW ->
            if even then
                x_ == x - 1 && y_ == y + 1

            else
                x_ == x && y_ == y + 1

        SE ->
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
