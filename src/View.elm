module View (..) where

import List exposing (..)
import Color exposing (..)
import Graphics.Element exposing (..)
import Graphics.Collage exposing (..)
import Debug

import Land

ratio a =
  a / 2

board : (Int, Int) -> List Land.Land -> Element
board (w,h) lands =
  ([]
   ++ (landForms w h lands)
  --  ++ (gridLine w h 5)
  --  ++ (gridLine w h 6)
   )
  |> map (origin w h)
  |> collage w h

origin : Int -> Int -> Form -> Form
origin w h form =
  move ((toFloat w / -2), (toFloat h / 2)) form

landForms : Int -> Int -> List Land.Land -> List Form
landForms w h lands =
  let
    hex = flip (hexagon 100) -- hexagon 100 y x
    foldLand land result =
      landForm land.hexagons |> append result
  in
    foldl foldLand [] lands


landForm : List Land.Hexagon -> List Form
landForm hexagons =
  map (uncurry (hexagon 100) >> filled blue) hexagons

-- gridLine : Int -> Int -> Int -> List Form
-- gridLine w h row =
--   let
--     hex = flip (hexagon 100) -- hexagon 100 y x
--   in
--     map (hex (row * -1) >> filled blue) [0..2]

-- x and y are grid coords
hexagon : Int -> Int -> Int -> Shape
hexagon size x y =
  let
    offsetOdds y x = if (rem y 2) == 0 then x else x + 0.5
    w = toFloat size
    h = ratio (toFloat size)
    x' = toFloat x
      |> (+) (0.5)
      |> offsetOdds y
      |> (*) ((sqrt 3) / 2 * w)
    y' = toFloat (y * -1)
      |> (+) (-0.5 * 4 / 3)
      |> (*) (h * 3 / 4)
    _ = Debug.log "hex" (x, y, x', y')
  in
    hexagonPoints x' y' w h
      |> roundPointList
      -- |> Debug.log "points"
      |> polygon

roundPoint (x,y) = (round x, round y)
floatPoint (x,y) = (toFloat x, toFloat y)

roundPointList : List (Float, Float) -> List (Float, Float)
roundPointList list =
    map roundPoint list
    |> map floatPoint

-- x and y are canvas coords
hexagonPoints : Float -> Float -> Float -> Float -> List (Float, Float)
hexagonPoints x y w h =
  haxgonPoint x y (w / 2) (h / 2)
    |> (\p -> map p [0..5])

haxgonPoint : Float -> Float -> Float -> Float -> Int -> (Float, Float)
haxgonPoint x y rwidth rheight i =
  (x + rwidth * (angle >> cos) i
  , y + rheight * (angle >> sin) i)

angle : Int -> Float
angle i =
  pi / 180 * angle_deg(i)

angle_deg (i) =
  60 * toFloat(i) + 30