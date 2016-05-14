module Hex (..) where
-- import List exposing (..)
import List.Nonempty as NE exposing (Nonempty, (:::))

import Land exposing (..)

type alias Point = (Float, Float)
type Side = NW | NE | E | SE | SW | W
allSides = case NE.fromList [NW, NE, E, SE, SW, W] of
  Just a -> a
  Nothing -> NE.fromElement NW

path : Int -> Int -> Cells -> NE.Nonempty Point
path w h list =
  let
    start = anyBorder list
    coord = fst start
    side = snd start
  in
    hexagon w h (fst coord) (snd coord)


-- return any coord that is on the border (is not completely surrounded)
anyBorderCoord : Cells -> Coord
anyBorderCoord list =
  NE.filter (hasFreeBorder list) (NE.head list) list
  |> NE.head

anyBorder : Cells -> (Coord, Side)
anyBorder list =
  let
    fold : Maybe (Coord, Side) -> (Coord, Side) -> (Coord, Side)
    fold border result = case border of
      Just a -> a
      Nothing -> result
  in
    NE.map (freeBorder list) list
    |> NE.foldl fold ((NE.head list), NW)




hasFreeBorder : Cells -> Coord -> Bool
hasFreeBorder list coord =
  NE.map (\s -> cellOnBorder coord s list) allSides
  |> NE.map fst
  |> NE.any isNothing

freeBorder : Cells -> Coord -> Maybe (Coord, Side)
freeBorder list coord =
  NE.map (\s -> cellOnBorder coord s list) allSides
  |> emptyBorders
  |> List.head

emptyBorders : NE.Nonempty (Maybe Coord, Side) -> List (Coord, Side)
emptyBorders list =
  let
    fold border result =
      case fst border of
        Just a -> (a, snd border) :: result
        Nothing -> result
  in
    List.foldl fold [] (NE.toList list)

isNothing a =
  case a of
    Nothing -> True
    Just a -> False

cellOnBorder : Coord -> Side -> Cells -> (Maybe Coord, Side)
cellOnBorder coord side list =
  let
    foldIsBorderOnSide other result =
      if isBorderOnSide coord side other then (Just other, side)
      else result
  in
    NE.foldl (foldIsBorderOnSide) (Nothing, side) list


isBorderOnSide : Coord -> Side -> Coord -> Bool
isBorderOnSide coord side other =
  let
    x = fst coord
    y = snd coord
    x' = fst other
    y' = snd other
    odd = y % 2 /= 0
  in
    case side of
      NW -> y == y' + 1 && ((odd && x == x') || (not odd && x == x' - 1))
      NE -> y == y' + 1 && ((odd && x == x' - 1) || (not odd && x == x'))
      E -> x == x' && y == y' + 1
      SE -> y == y' - 1 && ((odd && x == x') || (not odd && x == x' - 1))
      SW -> y == y' - 1 && ((odd && x == x' - 1) || (not odd && x == x'))
      W -> x == x' && y == y' - 1


-- x and y are grid coords
hexagon : Int -> Int -> Int -> Int -> NE.Nonempty Point
hexagon w h x y =
  let
    offsetOdds y x = if (rem y 2) == 0 then x else x + 0.5
    w' = toFloat w
    h' = toFloat h
    x' = toFloat x
      |> (+) (0.5)
      |> offsetOdds y
      |> (*) ((sqrt 3) / 2 * w')
    y' = toFloat (y * -1)
      |> (+) (-0.5 * 4 / 3)
      |> (*) (h' * 3 / 4)
    _ = Debug.log "hex" (x, y, x', y')
  in
    hexagonPoints x' y' w' h'
      |> roundPointList
      -- |> Debug.log "points"


-- hexagonDimensions : Int -> Int -> Coord -> (Int, Int, Int, Int)
-- hexagonDimensions w h coord =
--   let
--     x = fst coord
--     y = snd coord
--     offsetOdds y x = if (rem y 2) == 0 then x else x + 0.5
--     w' = toFloat w
--     h' = toFloat h
--     x' = toFloat x
--       |> (+) (0.5)
--       |> offsetOdds y
--       |> (*) ((sqrt 3) / 2 * w')
--     y' = toFloat (y * -1)
--       |> (+) (-0.5 * 4 / 3)
--       |> (*) (h' * 3 / 4)
--   in
--     (x', y', w', h')

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
  haxgonPoint x y (w / 2) (h / 2)
    |> (\p -> NE.map (p) allSides)

haxgonPoint : Float -> Float -> Float -> Float -> Side -> Point
haxgonPoint x y rwidth rheight side =
  (x + rwidth * (angle >> cos) (sideIndex side)
  , y + rheight * (angle >> sin) (sideIndex side))

sideIndex side =
  case side of
    NW -> 1
    NE -> 2
    E -> 3
    SE -> 4
    SW -> 5
    W -> 6

angle : Int -> Float
angle i =
  pi / 180 * angle_deg(i)

angle_deg (i) =
  60 * toFloat(i) + 30