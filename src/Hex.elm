module Hex exposing (landPath, Point)
-- import List.Nonempty as NE exposing (Nonempty, (:::))

import Land exposing (Cells, landBorders, allSides)
import Hexagons.Hex as HH exposing (Hex, Direction, (===))
import Hexagons.Layout as HL exposing (orientationLayoutPointy, Layout)

type alias Point = HL.Point

landPath : Float -> Float -> Cells -> List HL.Point
landPath w h cells =
  let
    size = (w / 2.0, h / 2.0)
    layout : Layout
    layout = { orientation = orientationLayoutPointy
    , size = size
    , origin = (fst size + 0.1, snd size + 0.1)
    }
  in
    landBorders cells
    |> List.map (\(coord, side) -> polygonLeftCorner layout coord side)

{-| Left/counter-clockwise point of Hex edge |-}
polygonLeftCorner : Layout -> Hex -> Direction -> HL.Point
polygonLeftCorner layout hex corner =
    let
        (x, y) = HL.hexToPoint layout hex
        offsetHex (x, y) (x_, y_) = (precision 2 <| x + x_, precision 2 <| y + y_) 
    in
      (offsetHex (x, y)) <| hexCornerOffset layout corner
        -- List.map  (offsetHex (x, y))
        --     <| List.map () [0..5]

{-| Round Float number to some division -}
precision : Int -> Float -> Float
precision division number =
    let
        k = toFloat <| 10 ^ division
    in
        ((toFloat << round) (number * k)) / k

{-| Calculate corner offset from a center of the Hex -}
hexCornerOffset : Layout -> Direction -> HL.Point
hexCornerOffset layout side =
    let
        (xl, yl) = layout.size
        startAngle = layout.orientation.start_angle
        angle = ((2.0 * pi) * (toFloat (sideIndex side) + startAngle)) / 6
        x = precision 2 <| xl * (cos angle)
        y = precision 2 <| yl * (sin angle)
    in
        (x, y)


sideIndex : Direction -> Int
sideIndex side =
  case side of
    HH.SW -> 1
    HH.W -> 2
    HH.NW -> 3
    HH.NE -> 4
    HH.E -> 5
    HH.SE -> 6

-- angle : Int -> Float
-- angle i =
--   pi / 180 * angle_deg(i)

-- angle_deg : Int -> Float
-- angle_deg (i) =
--   60 * toFloat(i) + 30

