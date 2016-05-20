module Land exposing (..)

import Maybe exposing (..)
import List.Nonempty as NE exposing (Nonempty, (:::))

type Side = NW | NE | E | SE | SW | W
type alias CubeCoord = (Int, Int, Int)
type alias Coord = (Int, Int)
type alias Cells = NE.Nonempty Coord
type alias Land = { hexagons: Cells}
type alias Map = NE.Nonempty Land
type alias Border = (Coord, Side)


nonemptyList : List a -> a -> NE.Nonempty a
nonemptyList list default =
  case NE.fromList list of
    Just a -> a
    Nothing -> NE.fromElement default


testLand : Map
testLand =
  NE.fromElement {hexagons =
    (nonemptyList [
       (0,0), (1,0), (2,0), (3,0)
    ,     (0,1), (1,1), (2,1), (3,1)
    ,  (0,2), (1,2), (2,2), (3,2)
    ,     (0, 3), (1,3), (2,3)
    ,  (0,4),        (2,4)
    ,                    (2,5)
    ] (0, 0))
  }


allSides : Nonempty Side
allSides = NW ::: NE ::: E ::: SE ::: SW ::: NE.fromElement W

defaultSide : Side
defaultSide = NW

  
landBorders : Cells -> Nonempty Border
landBorders cells =
  let
    (coord, side) = firstFreeBorder cells
  in
    case nextBorders cells coord (coord, side) side |> NE.fromList of
      Just a -> a
      Nothing -> NE.fromElement (coord, side)


nextBorders : Cells -> Coord -> Border -> Side -> List Border
nextBorders cells coord start side =
  let
    nside = nextSide side
  in
    (::) (coord, side) <| case cellOnBorder coord nside cells of
      Just c -> nextBorders cells c start << nextSide <| oppositeSide nside
      Nothing -> if fst start == coord && snd start == nside then []
                 else nextBorders cells coord start nside


nextSide : Side -> Side
nextSide side =
  case side of
    NW -> NE
    NE -> E
    E -> SE
    SE -> SW
    SW -> W
    W -> NW

prevSide : Side -> Side
prevSide side =
  case side of
    NW -> W
    NE -> NW
    E -> NW
    SE -> E
    SW -> SE
    W -> SW


oppositeSide : Side -> Side
oppositeSide = nextSide >> nextSide >> nextSide


firstFreeBorder : Cells -> Border
firstFreeBorder cells =
  case hasFreeBorder cells (NE.head cells) allSides of
    Just a -> (NE.head cells, a)
    Nothing -> NE.pop cells |> firstFreeBorder


hasFreeBorder : Cells -> Coord -> Nonempty Side -> Maybe Side
hasFreeBorder cells coord sides =
  let side = NE.head sides
  in
    if cellOnBorder coord side cells |> isNothing then Just side
    else if NE.length sides == 1 then Just <| NE.head sides
    else hasFreeBorder cells coord <| NE.pop sides


isNothing : Maybe a -> Bool
isNothing a =
  case a of
    Nothing -> True
    Just a -> False

cellOnBorder : Coord -> Side -> Cells -> Maybe Coord
cellOnBorder coord side cells =
  let
    other = NE.head cells
  in
    if other /= coord && isBorderOnSide coord side other then Just other
    else if NE.length cells > 1 then cellOnBorder coord side <| NE.pop cells
    else Nothing


isBorderOnSide : Coord -> Side -> Coord -> Bool
isBorderOnSide coord side other =
  let
    (x, y) = coord
    (x', y') = other
    even = y % 2 == 0
  in
    let
      is = 
        case side of
          W -> y' == y && x' == x - 1
          E -> y' == y && x' == x + 1
          NW -> if even then x' == x - 1 && y' == y - 1
                else x' == x && y' == y - 1
          NE -> if even then x' == x && y' == y - 1
                else x' == x + 1 && y' == y - 1
          SW -> if even then x' == x - 1 && y' == y + 1
                else x' == x && y' == y + 1
          SE -> if even then x' == x && y' == y + 1
                else x' == x + 1 && y' == y + 1
      -- _ = Debug.log "isBorderOnSide" (is, coord, side, other, even, x, y, x', y')
    in
      is

cubeCoord : Coord -> CubeCoord
cubeCoord coord =
  let
    (col, row) = coord
    x = col - (row - (row & 1)) / 2
    z = row
    y = -x-z
  in
    (x, y, z)

cubeDirection : Side -> CubeCoord
cubeDirection side =
  case side of
    NW -> (0, 1, -1)
    NE -> (1, 0, -1)
    E  -> (1, -1, 0)
    SE -> (0, -1, 1)
    SW -> (-1, 0, 1)
    W  -> (-1, 1, 0)

cubeNeighbour : CubeCoord -> Side -> CubeCoord
cubeNeighbour coord side =
  let
    (x, y, z) = coord
    (x', y', z') = cubeDirection side
  in
    (x + x', y + y', z + z')
