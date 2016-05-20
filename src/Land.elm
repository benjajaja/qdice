module Land exposing (..)

import Maybe exposing (..)
import List.Nonempty as NE exposing (Nonempty, (:::))

type alias Coord = (Int, Int)
type alias Cells = NE.Nonempty Coord
type alias Land = { hexagons: Cells}
type alias Map = NE.Nonempty Land


type Side = NW | NE | E | SE | SW | W
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
    (coord, side) = firstBorder cells
    prevBorder = prevSide side
  in
    case nextBorders cells coord (coord, prevBorder) prevBorder
         |> NE.fromList of
      Just a -> a
      Nothing -> NE.fromElement (coord, side)

nextBorders : Cells -> Coord -> Border -> Side -> List Border
nextBorders cells coord start side =
  let
    nside = nextSide side
    border = (coord, nside)
    ncell = cellOnBorder coord nside cells
  in
    case fst ncell of
      Just c -> border :: (nextBorders cells c start << nextSide << oppositeSide <| snd ncell)
      Nothing -> if fst start == coord && snd start == nside then [border]
                 else border :: (nextBorders cells coord start nside)


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
oppositeSide side =
  case side of
    NW -> SE
    NE -> SW
    E -> W
    SE -> NW
    SW -> NE
    W -> E


firstBorder : Cells -> Border
firstBorder cells =
  if NE.length cells == 1 then Debug.log "/!\\ firstBorder exhausted, using last cell: " (NE.head cells, defaultSide)
  else
    case hasFreeBorder cells (NE.head cells) allSides of
      Just a -> (NE.head cells, a)
      Nothing -> NE.pop cells |> firstBorder



hasFreeBorder : Cells -> Coord -> Nonempty Side -> Maybe Side
hasFreeBorder cells coord sides =
  let side = NE.head sides
  in if cellOnBorder coord side cells |> fst |> isNothing then Just side
  else if NE.length sides == 1 then Just <| NE.head sides
  else hasFreeBorder cells coord <| NE.pop sides


isNothing : Maybe a -> Bool
isNothing a =
  case a of
    Nothing -> True
    Just a -> False

cellOnBorder : Coord -> Side -> Cells -> (Maybe Coord, Side)
cellOnBorder coord side cells =
  let
    other = NE.head cells
  in
    if other /= coord && isBorderOnSide coord side other then (Just other, side)
    else if NE.length cells > 1 then cellOnBorder coord side <| NE.pop cells
    else (Nothing, side)


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
