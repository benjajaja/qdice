module Hex (..) where
-- import List exposing (..)
import List.Nonempty as NE exposing (Nonempty, (:::))

import Land exposing (..)

type alias Point = (Float, Float)
type Side = NW | NE | E | SE | SW | W

path : Int -> Int -> Cells -> NE.Nonempty Point
path w h list =
  let
    start = anyBorderHex list
  in
    hexagon w h (fst start) (snd start)

anyBorderHex : Cells -> Coord
anyBorderHex list =
  case List.head (List.filter (hasFreeBorder list) (NE.toList list)) of
    Just c -> c
    Nothing -> (0, 0)

hasFreeBorder : Cells -> Coord -> Bool
hasFreeBorder list coord =
  let
    f m =
      case m of
        Nothing -> False
        Just a -> True
  in
    List.map (\s -> cellOnBorder coord s list) [NW, NE, E, SE, SW, W]
    |> List.any (not << f)
  

cellOnBorder : Coord -> Side -> Cells -> Maybe (Coord, Side)
cellOnBorder coord side list =
  let
    foldIsBorderOnSide other result =
      if isBorderOnSide coord side other then Just (other, side)
      else Nothing
  in
    NE.foldl (foldIsBorderOnSide) Nothing list


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

roundPoint (x,y) = (round x, round y)
floatPoint (x,y) = (toFloat x, toFloat y)

roundPointList : NE.Nonempty Point -> NE.Nonempty Point
roundPointList list =
    NE.map roundPoint list
    |> NE.map floatPoint

sideCount = 1 ::: 2 ::: 3 ::: 4 ::: (NE.fromElement 5)

-- x and y are canvas coords
hexagonPoints : Float -> Float -> Float -> Float -> NE.Nonempty Point
hexagonPoints x y w h =
  haxgonPoint x y (w / 2) (h / 2)
    |> (\p -> NE.map (p) sideCount)

haxgonPoint : Float -> Float -> Float -> Float -> Int -> Point
haxgonPoint x y rwidth rheight i =
  (x + rwidth * (angle >> cos) i
  , y + rheight * (angle >> sin) i)

angle : Int -> Float
angle i =
  pi / 180 * angle_deg(i)

angle_deg (i) =
  60 * toFloat(i) + 30