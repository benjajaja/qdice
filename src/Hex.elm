module Hex exposing (Point, borderLeftCorner, center)

import Hexagons.Hex as HH exposing (Hex, Direction, (===))
import Hexagons.Layout as HL exposing (Point, Layout)

type alias Point = HL.Point

{- Left/counter-clockwise point of Hex edge -}
borderLeftCorner : Layout -> Hex -> Direction -> Point
borderLeftCorner layout hex corner =
    let
        (x, y) = center layout hex
        (x_, y_) = hexCornerOffset layout.size layout.orientation.start_angle corner
    in
        (precision 2 <| x + x_, precision 2 <| y + y_)
        -- Debug.log "xy" <| (x + x_, y + y_)

center : Layout -> Hex -> Point
center layout hex = HL.hexToPoint layout hex

{- Round Float number to some division -}
precision : Int -> Float -> Float
precision division number =
    let
        k = toFloat <| 10 ^ division
    in
        ((toFloat << round) (number * k)) / k

{- Calculate corner offset from a center of the Hex -}
hexCornerOffset : (Float, Float) -> Float -> Direction -> Point
hexCornerOffset (w, h) startAngle side =
    let
        angle = sideAngle startAngle side
    in
        (w * (cos angle), h * (sin angle))

sideAngle : Float -> Direction -> Float
sideAngle startAngle side = ((2.0 * pi) * (toFloat (sideIndex side) + startAngle)) / 6

sideIndex : Direction -> Int
sideIndex side =
  case side of
    HH.SW -> 1
    HH.W -> 2
    HH.NW -> 3
    HH.NE -> 4
    HH.E -> 5
    HH.SE -> 6

