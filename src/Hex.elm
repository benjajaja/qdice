module Hex exposing (..)
-- import List exposing (..)
import List.Nonempty as NE exposing (Nonempty, (:::))

import Land exposing (..)

type alias Point = (Float, Float)
type Side = NW | NE | E | SE | SW | W
type alias Border = (Coord, Side)
type alias Size = (Int, Int)

allSides : Nonempty Side
allSides = NW ::: NE ::: E ::: SE ::: SW ::: NE.fromElement W

defaultSide : Side
defaultSide = NW

landPath : Int -> Int -> Cells -> Nonempty Point
landPath w h cells =
  -- NE.map (\s -> (hexpoint (w,h) (NE.head cells) s)) (NW ::: (NE.fromElement E))
  -- NE.map (\s -> (hexpoint (w,h) (NE.head cells) s)) allSides
  let
    (coord, side) = firstBorder cells
    size = (w,h)
    start = hexpoint size coord side
    borders = nextBorders size cells coord (coord, (prevSide side)) (prevSide side)
    -- |> List.reverse
    |> (\l -> l ++ [start])
    |> NE.fromList
    _ = Debug.log "stack" (coord, side)
  in
    case borders of
      Nothing -> NE.fromElement start
      Just a -> a

nextBorders : Size -> Cells -> Coord -> Border -> Side -> List Point
nextBorders size cells coord start side =
  let
    nside = nextSide side
    point = hexpoint size coord nside
    ncell = cellOnBorder coord nside cells
    debugValue = toString (coord, side, nside, not << isNothing <| fst ncell, point)
    debugMe = case fst ncell of
      Just _ -> Debug.log "stack start" debugValue
      Nothing -> if fst start == coord && snd start == nside then Debug.log "stack start" debugValue
                  else ""
  in
    case fst ncell of
      Just c -> (point :: (nextBorders size cells c start (nextSide (oppositeSide (snd ncell)))))
      Nothing -> if fst start == coord && snd start == nside then [point]
                  else (point :: (nextBorders size cells coord start nside))
      



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
    if other == coord then
      if NE.length cells > 1 then cellOnBorder coord side <| NE.pop cells
      else (Nothing, side)
    else if isBorderOnSide coord side other then (Just other, side)
    else
      if NE.length cells > 1 then cellOnBorder coord side <| NE.pop cells
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


hexpoint : Size -> Coord -> Side -> Point
hexpoint size coord side =
  let
    (w, h) = size
    (x, y, w', h') = (hexagonDimensionsCoord w h coord)
  in
    hexagonPoint x y w' h' side

-- x and y are grid coords
hexagon : Int -> Int -> Int -> Int -> NE.Nonempty Point
hexagon w h x y =
  let
    (x', y', w', h') = hexagonDimensions w h x y
  in
    hexagonPoints x' y' w' h'
    |> roundPointList
    |> Debug.log "points"

hexagonDimensionsCoord : Int -> Int -> Coord -> (Float, Float, Float, Float)
hexagonDimensionsCoord w h coord = hexagonDimensions w h (fst coord) (snd coord)

-- x and y are grid coords
hexagonDimensions : Int -> Int -> Int -> Int -> (Float, Float, Float, Float)
hexagonDimensions w h x y =
  let
    offsetOdds y x = if (rem y 2) == 0 then x else x + 0.5
    w' = toFloat w
    h' = toFloat h
    x' = toFloat x
      |> (+) (0.5)
      |> offsetOdds y
      |> (*) ((sqrt 3) / 2 * w')
    y' = toFloat y
      |> (+) (0.5 * 4 / 3)
      |> (*) (h' * 3 / 4)
  in
    (x', y', w' / 2, h' / 2)

roundPoint (x,y) = (round x, round y)
floatPoint (x,y) = (toFloat x, toFloat y)

roundPointList : NE.Nonempty Point -> NE.Nonempty Point
roundPointList list =
    NE.map roundPoint list
    |> NE.map floatPoint

-- hexagonSidePoint : Coord -> Side -> Point
-- hexagonSidePoint w h coord side =
  

-- x and y are canvas coords
hexagonPoints : Float -> Float -> Float -> Float -> NE.Nonempty Point
hexagonPoints x y w h =
  hexagonPoint x y w h
    |> (\p -> NE.map (p) allSides)

hexagonPoint : Float -> Float -> Float -> Float -> Side -> Point
hexagonPoint x y rwidth rheight side =
  (x + rwidth * (angle >> cos) (sideIndex side)
  , y + rheight * (angle >> sin) (sideIndex side))
  -- |> roundPoint |> floatPoint

sideIndex : Side -> Int
sideIndex side =
  case side of
    NW -> 3
    NE -> 4
    E -> 5
    SE -> 6
    SW -> 1
    W -> 2

angle : Int -> Float
angle i =
  pi / 180 * angle_deg(i)

angle_deg : Int -> Float
angle_deg (i) =
  60 * toFloat(i) + 30
