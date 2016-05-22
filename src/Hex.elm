module Hex exposing (..)
-- import List exposing (..)
import List.Nonempty as NE exposing (Nonempty, (:::))

import Land exposing (..)

type alias Size = (Int, Int)
type alias Point = (Float, Float)

landPath : Int -> Int -> Cells -> Nonempty Point
landPath w h cells =
  landBorders cells
  |> NE.map (\(coord, side) -> hexpoint (w, h) coord side)


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
    -- |> Debug.log "points"

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
